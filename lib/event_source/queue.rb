# frozen_string_literal: true

module EventSource
  # DSL to store and forward sets of messages to consumers
  class Queue
    # @attr_reader [Object] queue_proxy the protocol-specific class supporting this DSL
    # @attr_reader [String] name
    # @attr_reader [Hash] bindings
    attr_reader :queue_proxy, :name, :bindings

    def initialize(queue_proxy, name, bindings = {})
      @queue_proxy = queue_proxy
      @name = name
      @bindings = bindings
      @subject = ::Queue.new
      @registered_actions = []
    end

    # def subscribe(subscriber_klass, &block)
    #   @queue_proxy.subscribe(subscriber_klass, bindings, &block)
    # end
    # def add_subscriber(); end

    # Add an entry to the queue
    # @param [Mixed] value an action to post to queue for processing
    def enqueue(value)
      @subject.push(value)
    end

    # Return an entry from the queue for processing
    # @param [Boolean] non_block whether the enrty is sync or async
    def dequeue(non_block = false)
      @subject.pop(non_block)
    end

    # @api private
    def add_message
      # For each subscriber,
    end

    # Stop the queue frorm accepting new entries
    def close
      @subject.close
    end

    # Is the queue accepting new entries?
    # @return [Boolean]
    def closed?
      @subject.closed?
    end

    # Register an action to be performed, with a resolver class and key.
    def register_action(resolver, key)
      @registered_actions << [resolver, key]
    end

    def actions
      @registered_actions.map do |ra|
        ra.first.executable_for(ra.last)
      end
    end
  end
end
