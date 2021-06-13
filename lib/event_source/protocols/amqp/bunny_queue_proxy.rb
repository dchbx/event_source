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
        attr_reader :subject, :channel_proxy, :exchange_name

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
          bindings = async_api_channel_item[:bindings]

          queue_bindings = channel_item_queue_bindings_for(bindings)
          @exchange_name = exchange_name_from_queue(queue_bindings[:name])
          @subject = bunny_queue_for(queue_bindings)
          bind_exchange(@exchange_name, async_api_channel_item[:subscribe])
          subject
        end

        # Find a Bunny queue that matches the configuration of an {EventSource::AsyncApi::ChannelItem}
        def bunny_queue_for(queue_bindings)
          queue =
            Bunny::Queue.new(
              channel_proxy,
              queue_bindings[:name],
              queue_bindings.slice(:durable, :auto_delete, :vhost, :exclusive)
            )

          logger.info "Found or created Bunny queue #{queue.name}"
          queue
        end

        # Bind this Queue to the Exchange
        def bind_exchange(exchange_name, async_api_subscribe_operation)
          operation_bindings = async_api_subscribe_operation[:bindings][:amqp]
          channel_proxy.bind_queue(@subject.name, exchange_name, {routing_key: operation_bindings[:routing_key]})
          logger.info "Queue #{@subject.name} bound to exchange #{exchange_name}"
        rescue Bunny::NotFound => e
          raise EventSource::AsyncApi::Error::ExchangeNotFoundError,
                "exchange #{name} not found. got exception #{e.to_s}"
        end

        # Construct and subscribe a consumer_proxy with the queue
        # @param [Object] subscriber_klass Subscriber class
        # @param [Hash] options Subscribe operation bindings
        # @param [Proc] block Code block to execute when event is received
        # @return [BunnyConsumerProxy] Consumer proxy instance
        def subscribe(subscriber_klass, options, &block)
          operation_bindings = convert_to_bunny_options(options[:amqp])
          consumer_proxy = consumer_proxy_for(operation_bindings)

          # redelivered?
          consumer_proxy.on_delivery do |delivery_info, metadata, payload|
            if block_given?
              @channel_proxy.instance_exec(
                delivery_info,
                metadata,
                payload,
                &block
              )
            end
            subscriber_instance = subscriber_klass.new
            if subscriber_instance.respond_to?(queue_name)
              subscriber_instance.send(queue_name, payload)
            end
          end

          @subject.subscribe_with(consumer_proxy)
        end

        def consumer_proxy_for(operation_bindings)
          BunnyConsumerProxy.new(
            @subject.channel,
            @subject,
            '',
            operation_bindings[:no_ack],
            operation_bindings[:exclusive],
          )
        end

        def respond_to_missing?(name, include_private); end

        # Forward all missing method calls to the Bunny::Queue instance
        def method_missing(name, *args)
          @subject.send(name, *args)
        end

        private

        def convert_to_bunny_options(options)
          operation_bindings = options.slice(:exclusive, :on_cancellation, :arguments)
          operation_bindings[:no_ack] = !options[:ack] if options[:ack]
          operation_bindings
        end

        def channel_item_queue_bindings_for(bindings)
          if async_api_channel_item_bindings_valid?(bindings)
            bindings[:amqp][:queue]
          else
            raise EventSource::Protocols::Amqp::Error::ChannelBindingContractError,
                  "Expected queue bindings: #{bindings}"
          end
        end

        def async_api_channel_item_bindings_valid?(bindings)
          result =
            EventSource::Protocols::Amqp::Contracts::ChannelBindingContract.new
              .call(bindings)
          if result.success?
            true
          else
            raise EventSource::Protocols::Amqp::Error::ChannelBindingContractError,
                  "Error(s) #{result.errors.to_h} validating: #{bindings}"
          end
        end

        def exchange_name_from_queue(queue_name)
          queue_name.match(/^\w+\.(.+)/)[1]
        end
      end
    end
  end
end
