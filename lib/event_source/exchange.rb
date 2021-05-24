# frozen_string_literal: true

module EventSource
  # Component that accepts and routes messages to the correct {EventSource::Queue}
  class Exchange
    # @attr_reader [Hash] bindings
    # {EventSource::Queue} within a broker
    attr_reader :bindings, :exchange_proxy

    ADAPTER_METHODS = %i[publish bind]

    def initialize(exchange_proxy, async_api_publish_operation)
      @exchange_proxy = exchange_proxy
      @bindings = async_api_publish_operation[:bindings]
    end

    def publish(payload, opts = {})
      @exchange_proxy.publish(payload, opts.merge(bindings))
    end

    # Create a virtual link between this Exchange and a {EventSource::Queue}
    # or anonther Exchange within a broker
    def bind(*args)
      @exchange_proxy.bind(*args)
    end
  end
end
