# frozen_string_literal: true

module EventSource
  module Protocols
    module Amqp
      # Create and manage a RabbitMQ Queue instance using Bunny client.  Provides an interface
      # that responds to AMQP adapter pattern DSL.  Also serves as proxy for Bunny::Queue object
      # enabling access to its API.
      # @since 0.4.0
      class BunnyQueueProxy
        include EventSource::Logging

        # @attr_reader [Bunny::Queue] subject the queue object
        # @attr_reader [EventSource::Protcols::Amqp::BunnyChannelProxy] channel_proxy the channel_proxy used to access this queue
        # @attr_reader [String] exchange_name the Exchange to which this to bind this Queue
        attr_reader :subject, :channel_proxy, :exchange_name, :consumers

        # @param channel_proxy [EventSource::Protocols::Amqp::BunnyChannelProxy] channel_proxy wrapping Bunny::Channel object
        # @param async_api_channel_item [Hash] {EventSource::AsyncApi::ChannelItem} definition and bindings
        # @option async_api_channel_item [String] :name queue name
        # @option async_api_channel_item [String] :durable
        # @option async_api_channel_item [String] :auto_delete
        # @option async_api_channel_item [String] :exclusive
        # @option async_api_channel_item [String] :vhost ('/')
        # @return [Bunny::Queue]
        def initialize(channel_proxy, async_api_channel_item)
          @channel_proxy = channel_proxy
          @async_api_channel_item = async_api_channel_item
          bindings = async_api_channel_item.bindings
          @consumers = []

          bindings.deep_symbolize_keys!
          queue_bindings = channel_item_queue_bindings_for(bindings)
          @exchange_name = exchange_name_from_queue(queue_bindings[:name])
          @subject = bunny_queue_for(queue_bindings)
          bind_exchange(@exchange_name, async_api_channel_item.subscribe)
          subject
        end

        # Find a Bunny queue that matches the configuration of an {EventSource::AsyncApi::ChannelItem}
        def bunny_queue_for(queue_bindings)
          queue =
            Bunny::Queue.new(
              channel_proxy.subject,
              queue_bindings[:name],
              queue_bindings.slice(:durable, :auto_delete, :vhost, :exclusive)
            )

          logger.info "Found or created Bunny queue #{queue.name}"
          queue
        end

        # Bind this Queue to the Exchange
        def bind_exchange(exchange_name, async_api_subscribe_operation)
          operation_bindings =
            async_api_subscribe_operation.bindings.amqp.symbolize_keys || {}
          channel_proxy.bind_queue(
            @subject.name,
            exchange_name,
            { routing_key: operation_bindings[:routing_key] }
          )
          logger.info "Queue #{@subject.name} bound to exchange #{exchange_name}"
        rescue Bunny::NotFound => e
          raise EventSource::Protocols::Amqp::Error::ExchangeNotFoundError,
                "exchange #{name} not found. got exception #{e}"
        end

        def subscribe(subscriber_klass, bindings)
          options = convert_to_subscribe_options(bindings[:amqp])
          prefetch = convert_subscriber_prefetch(bindings[:amqp])

          logger.debug 'Queue#subscribe options:'
          logger.debug options.merge({ prefetch: prefetch }).inspect

          @channel_proxy.subject.prefetch(prefetch)

          if options[:block]
            spawn_thread(options) { add_consumer(subscriber_klass, options) }
          else
            add_consumer(subscriber_klass, options)
          end
        end

        def spawn_thread(options)
          sub_thread = Thread.new { yield }
          while !@channel_proxy.subject.any_consumers?
            sub_thread.run
            Thread.pass
            sleep 0.05
          end
        end

        def add_consumer(subscriber_klass, options)
          @subject.subscribe(options) do |delivery_info, metadata, payload|
            on_receive_message(
              subscriber_klass,
              delivery_info,
              metadata,
              payload
            )
          end
        end

        def convert_to_subscribe_options(options)
          options.symbolize_keys!
          subscribe_options = options.slice(:exclusive, :on_cancellation)
          subscribe_options[:manual_ack] = options[:ack]
          subscribe_options[:block] =
            (options[:block].to_s == 'true') ? true : false
          subscribe_options
        end

        def convert_subscriber_prefetch(options)
          symbolized_options = options.symbolize_keys
          return 0 if symbolized_options[:prefetch].nil?
          symbolized_options[:prefetch].to_i
        end

        def resolve_subscriber_routing_keys(channel, operation); end

        def on_receive_message(
          subscriber_klass,
          delivery_info,
          metadata,
          payload
        )
          logger.debug '**************************'
          logger.debug subscriber_klass.inspect
          logger.debug delivery_info.inspect
          logger.debug metadata.inspect
          logger.debug payload.inspect

          executable = find_executable(subscriber_klass, delivery_info)
          return unless executable

          subscriber = subscriber_klass.new
          subscriber.channel = @subject.channel
          payload = decode_payload(payload)
          subscription_handler =
            EventSource::Protocols::Amqp::BunnyConsumerHandler.new(
              subscriber,
              delivery_info,
              metadata,
              payload,
              &executable
            )
          subscription_handler.run
        rescue Bunny::Exception => e
          logger.error "Bunny Consumer Error \n  message: #{e.message} \n  backtrace: #{e.backtrace.join("\n")}"
        ensure
          subscriber = nil
        end

        # Decodes the given payload based on the `contentEncoding` specified in the AsyncAPI *_subscribe.yml message bindings.
        #
        # For example, if `contentEncoding` is set to `application/zlib`, the payload will be decompressed using zlib.
        # If no `contentEncoding` is provided, the payload will be returned unchanged.
        #
        # @param payload [String] The payload to be decoded.
        # @return [String] The decoded payload, or the original payload if no encoding is specified.
        # @raise [EventSource::Error::PayloadDecodeError] if the decoding process fails.
        def decode_payload(payload)
          async_api_subscribe_operation = @async_api_channel_item.subscribe
          return payload unless async_api_subscribe_operation.message
          
          message_bindings = async_api_subscribe_operation.message['bindings']
          encoding = message_bindings.first[1]['contentEncoding'] if message_bindings
          return payload unless encoding

          output = EventSource::Operations::MimeDecode.new.call(encoding, payload)
          if output.success?
            output.value!
          else
            logger.error "Failed to decompress message \n  due to: #{output.failure}"
            raise EventSource::Error::PayloadDecodeError, output.failure
          end
        end

        def find_executable(subscriber_klass, delivery_info)
          subscriber_suffix = subscriber_klass_name_to_suffix(subscriber_klass)

          find_executable_for_routing_key(subscriber_klass, delivery_info, subscriber_suffix) ||
            find_default_executable(subscriber_klass, subscriber_suffix)
        end

        def respond_to_missing?(name, include_private); end

        # Forward all missing method calls to the Bunny::Queue instance
        def method_missing(name, *args)
          @subject.send(name, *args)
        end

        private

        def subscriber_klass_name_to_suffix(subscriber_klass)
          subscriber_klass.name.downcase.gsub("::", '_')
        end

        def find_executable_for_routing_key(subscriber_klass, delivery_info, subscriber_suffix)
          return unless delivery_info.routing_key

          routing_key = [app_name, delivery_info.routing_key].join(delimiter)
          subscriber_klass.executable_for(routing_key + "_#{subscriber_suffix}")
        end

        def find_default_executable(subscriber_klass, subscriber_suffix)
          default_routing_key = [app_name, exchange_name].join(delimiter)
          subscriber_klass.executable_for(default_routing_key + "_#{subscriber_suffix}")
        end

        def delimiter
          EventSource.delimiter(:amqp)
        end

        def app_name
          EventSource.app_name
        end

        def convert_to_consumer_options(options)
          consumer_options =
            options.slice(:exclusive, :on_cancellation, :arguments)
          consumer_options[:no_ack] = !options[:ack] if options[:ack]
          consumer_options
        end

        def channel_item_queue_bindings_for(bindings)
          result =
            EventSource::Protocols::Amqp::Contracts::ChannelBindingContract.new
              .call(bindings)
          if result.success?
            result.values[:amqp][:queue]
          else
            raise EventSource::Protocols::Amqp::Error::ChannelBindingContractError,
                  "Error(s) #{result.errors.to_h} validating: #{bindings}"
          end
        end

        # "on_<app_name>.<exchange_name>"
        def exchange_name_from_queue(queue_name)
          queue_name.match(/^\w+\.(.+)/)[1]
        end
      end
    end
  end
end
