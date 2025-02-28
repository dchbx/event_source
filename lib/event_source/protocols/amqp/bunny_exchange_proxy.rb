# frozen_string_literal: true

require 'securerandom'

module EventSource
  module Protocols
    module Amqp
      # Create and manage a RabbitMQ Exchange instance using Bunny client
      # @attr_reader [Bunny::Channel] channel AMQP Channel on which this Queue was created
      # @since 0.4.0
      class BunnyExchangeProxy
        include EventSource::Logging

        # @attr_reader [Bunny::Exchange] subject the exchange object
        # @attr_reader [EventSource::Protcols::Amqp::BunnyChannelProxy] channel_proxy the channel_proxy used to create this exchange
        attr_reader :subject, :channel_proxy

        DefaultMimeType = 'application/json'.freeze

        # @param [EventSource::AsyncApi::Channel] channel_proxy instance on which to open this Exchange
        # @param [Hash<EventSource::AsyncApi::Exchange>] exchange_bindings instance with configuration for this Exchange
        def initialize(channel_proxy, exchange_bindings)
          @channel_proxy = channel_proxy
          @subject = bunny_exchange_for(exchange_bindings)
        end

        def bunny_exchange_for(bindings)
          exchange =
            Bunny::Exchange.new(
              channel_proxy.subject,
              bindings[:type],
              bindings[:name],
              bindings.slice(:durable, :auto_delete, :vhost)
            )
          exchange.on_return do |return_info, properties, content|
            logger.error "Got a returned message: #{content} with return info: #{return_info}, properties: #{properties}"
          end

          logger.info "Found or created Bunny exchange #{exchange.name}"
          exchange
        end

        # Publish a message to this Exchange
        # @param [Mixed] payload the message content
        # @param [Hash] publish_bindings
        # @param [Hash] headers
        def publish(payload:, publish_bindings:, headers: {})
          bunny_publish_bindings = sanitize_bindings((publish_bindings || {}).to_h)
          bunny_publish_bindings[:correlation_id] = headers.delete(:correlation_id) if headers[:correlation_id]
          bunny_publish_bindings[:message_id] = headers.delete(:message_id) if headers[:message_id]
          bunny_publish_bindings[:headers] = headers unless headers.empty?

          logger.debug "BunnyExchange#publish  publishing message with bindings: #{bunny_publish_bindings.inspect}"

          @subject.publish(payload, bunny_publish_bindings)

          logger.debug "BunnyExchange#publish  published message: #{payload}"
          logger.debug "BunnyExchange#publish  published message to exchange: #{@subject.name}"
        end

        def respond_to_missing?(name, include_private); end

        # Forwards all missing method calls to the Bunny::Queue instance
        def method_missing(name, *args)
          @subject.send(name, *args)
        end

        private

        def message_id
          SecureRandom.uuid
        end

        # Filtering and renaming AsyncAPI Operation bindings to Bunny/RabitMQ
        #   bindings
        #
        # Auto-generated
        #   :message_id
        #
        # Supported Bunny Bindings
        #   :expiration, :priority, :mandatory, :user_id, :timestamp, :persistent,
        #   :reply_to, :content_encoding, :type, :message_id, :routing_key,
        #   :content_type, :correlation_id, :app_id
        #
        # Unsupported AsyncApi Bindings
        #   bcc: ['external.audit']
        # @return [Hash] sanitized Bunny/RabitMQ bindings
        def sanitize_bindings(bindings)
          options = bindings[:amqp]&.symbolize_keys || {}
          operation_bindings = options.slice(
            :type, :content_type, :correlation_id, :correlation_id,
            :priority, :message_id, :app_id, :expiration, :mandatory, :routing_key
          )

          # operation_bindings[:routing_key] = options[:cc] if options[:cc]
          operation_bindings[:persistent] = true if options[:deliveryMode] == 2
          operation_bindings[:timestamp] = DateTime.now.strftime('%Q').to_i if options[:timestamp]
          operation_bindings[:reply_to] = options[:replyTo] if options[:replyTo]
          operation_bindings[:content_encoding] = options[:contentEncoding] if options[:contentEncoding]
          operation_bindings[:user_id] = options[:userId] if options[:userId]
          operation_bindings
        end
      end
    end
  end
end
