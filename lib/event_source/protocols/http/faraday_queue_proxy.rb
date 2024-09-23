# frozen_string_literal: true

module EventSource
  module Protocols
    module Http
      # Create and manage an {EventSource::Queue} instance for Faraday supporting an interface
      # compliant with the EventSource DSL.  Also serves as {EventSource::Queue} proxy
      # enabling access to its API.
      # @since 0.5.0
      class FaradayQueueProxy
        include EventSource::Logging

        # @attr_reader [EventSource::Queue] subject the queue object
        # @attr_reader [EventSource::Protcols::Http::FaradayChannelProxy] channel_proxy the instance used to access this queue
        # @attr_reader [String] exchange_name the Exchange to which this to bind this Queue
        attr_reader :subject, :channel_proxy, :exchange_name

        # @param channel_proxy [EventSource::Protocols::http::BunnyChannelProxy]  channel_proxy wrapping Bunny::Channel object
        # @param async_api_channel_item [Hash] {EventSource::AsyncApi::Channel} definition and bindings
        # @option channel_bindings [String] :name queue name
        # @option channel_bindings [String] :durable
        # @option channel_bindings [String] :auto_delete
        # @option channel_bindings [String] :exclusive
        # @option channel_bindings [String] :vhost ('/')
        # @return [EventSource::Queue]
        def initialize(channel_proxy, async_api_channel_item)
          @channel_proxy = channel_proxy
          @exchange_name = channel_proxy.name
          queue_bindings = async_api_channel_item.subscribe.bindings.http
          @subject = faraday_queue_for(queue_bindings)
        end

        # Find an {EventSource::Queue} that matches the configuration of an {EventSource::AsyncApi::ChannelItem}
        def faraday_queue_for(_queue_bindings)
          queue =
            EventSource::Queue.new(
              self,
              "on_#{channel_proxy.name.match(%r{^(/)?(.*)})[2].gsub(%r{/}, '_')}"
            )
          logger.info "Found or created Faraday queue #{queue.name}"
          queue
        end

        def actions
          @subject.actions
        end

        # Construct and subscribe a consumer_proxy with the queue
        # @param [Object] subscriber_klass Subscriber class
        # @return [Queue] Queue instance
        def subscribe(subscriber_klass, _options)
          unique_key = [app_name, formatted_exchange_name].join(delimiter)
          subscription_key = [app_name, formatted_exchange_name].join(delimiter)
          subscriber_suffix = subscriber_klass.name.downcase.gsub('::', '_')
          unique_key = subscription_key + "_#{subscriber_suffix}"
          logger.info "FaradayQueueProxy#register_subscription Subscriber Class #{subscriber_klass}"
          logger.info "FaradayQueueProxy#register_subscription Unique_key #{unique_key}"
          @subject.register_action(subscriber_klass, unique_key)
        end

        def consumer_proxy_for(operation_bindings)
          FaradayConsumerProxy.new(
            @subject.channel,
            @subject,
            '',
            operation_bindings[:no_ack],
            operation_bindings[:exclusive]
          )
        end

        def respond_to_missing?(name, include_private); end

        # Forward all missing method calls to the EventSource::Queue instance
        def method_missing(name, *args)
          @subject.send(name, *args)
        end

        private

        def delimiter
          EventSource.delimiter(:http)
        end

        def app_name
          EventSource.app_name
        end

        def formatted_exchange_name
          exchange_name.to_s.split(delimiter).reject(&:empty?).join(delimiter)
        end

        def convert_to_faraday_options(options)
          operation_bindings = {}
          operation_bindings[:no_ack] = !options[:ack] if options.key?(:ack)
          operation_bindings
        end

        def channel_item_queue_bindings_for(bindings)
          if async_api_channel_item_bindings_valid?(bindings)
            bindings[:http][:queue]
          else
            raise EventSource::Protocols::Http::Error::ChannelBindingContractError,
                  "Expected queue bindings: #{bindings}"
          end
        rescue StandardError
          {}
        end

        # FIX ME: HTTP don't have channel bindings according to AsyncApi protocol
        def async_api_channel_item_bindings_valid?(_bindings)
          true

          # result =
          #   EventSource::Protocols::Http::Contracts::ChannelBindingContract.new
          #                                                                  .call(bindings)
          # if result.success?
          #   true
          # else
          #   raise EventSource::Protocols::Http::Error::ChannelBindingContractError,
          #         "Error(s) #{result.errors.to_h} validating: #{bindings}"
          # end
        end
      end
    end
  end
end
