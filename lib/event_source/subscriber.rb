# frozen_string_literal: true

require 'dry/inflector'
require 'concurrent/map'

module EventSource
  # Mixin that provides a DSL to register and receive published {EventSource::Event}
  #   messages
  class Subscriber < Module
    send(:include, Dry.Equalizer(:protocol, :publisher_key))

    # include Dry.Equalizer(:protocol, :publisher_key)

    # @attr_reader [Symbol] protocol communication protocol used by this
    #   subscriber (for example: :amqp)
    # @attr_reader [String] publisher_key the unique key for publisher broadcasting event
    #   messsages that this subsciber will receive
    # TODO: Ram update the references to :publisher_key to reflect publisher or publish_operation
    attr_reader :protocol, :publisher_key

    # @api private
    def self.subscriber_container
      @subscriber_container ||= Concurrent::Map.new
    end

    def self.executable_container
      @executable_container ||= Concurrent::Map.new
    end

    def self.[](exchange_ref)
      # TODO: validate publisher already exists
      # raise EventSource::Error::PublisherAlreadyRegisteredError.new(id) if registry.key?(id)

      new(exchange_ref.first[0], exchange_ref.first[1])
    end

    # @api private
    def initialize(protocol, publisher_key)
      super()
      @protocol = protocol
      @publisher_key = publisher_key
    end

    def included(base)
      self.class.subscriber_container[base] = {
        publisher_key: publisher_key,
        protocol: protocol
      }
      base.extend ClassMethods

      TracePoint.trace(:end) do |t|
        if base == t.self
          base.create_subscription
          t.disable
        end
      end
    end

    # methods to register subscriptions
    module ClassMethods
      def publisher_key
        EventSource::Subscriber.subscriber_container[self][:publisher_key]
      end

      def protocol
        EventSource::Subscriber.subscriber_container[self][:protocol]
      end

      def channel_name
        publisher_key.to_sym
      end

      def subscribe(queue_name, &block)
        identifier = queue_name.to_s.match(/^on_(.*)/)[1]
        
        routing_key = 
            if ("#{app_name}_" + publisher_key.to_s.gsub(delimiter, '_')) == identifier
              [app_name, publisher_key].map(&:to_s).join(delimiter)
            else
              [app_name, publisher_key, identifier].map(&:to_s).join(delimiter)
            end

        if block_given?
          EventSource::Subscriber.executable_container[routing_key] = block
        end
      end

      def app_name
        EventSource.app_name
      end

      def create_subscription
        subscribe_operation = subscribe_operation_for("on_#{app_name}.#{publisher_key}")

        unless subscribe_operation
          raise EventSource::Error::SubscriberNotFound,
                "Unable to find queue #{queue_name}"
        end

        subscribe_operation.subscribe(self)
      end

      def executable_for(name)
        EventSource::Subscriber.executable_container[name]
      end

      def subscribe_operation_for(subscribe_operation_name)
        connection_manager.find_subscribe_operation({
          protocol: protocol, subscribe_operation_name: subscribe_operation_name
        })
      end

      def connection_manager
        EventSource::ConnectionManager.instance
      end

      def delimiter
        EventSource.delimiter(protocol)
      end
    end
  end
end
