# frozen_string_literal: true

require 'dry/inflector'
require 'concurrent/map'

module EventSource
  # Mixin that provides a DSL to register and forward {EventSource::Event} messages
  class Publisher < Module
    send(:include, Dry.Equalizer(:protocol, :publisher_key))

    # include Dry.Equalizer(:protocol, :exchange)

    # @attr_reader [Symbol] protocol communication protocol used by this
    #   publisher (for example: amqp)
    # @attr_reader [String] exchange name of the Exchange where event
    #   messages are published
    attr_reader :protocol, :publisher_key

    # Internal publisher registry, which is used to identify them globally
    #
    # This allows us to have listener classes that can subscribe to events
    # without having access to instances of publishers yet.
    #
    # @api private
    def self.publisher_container
      @publisher_container ||= Concurrent::Map.new
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
      self.class.publisher_container[base] = {
        publisher_key: publisher_key,
        protocol: protocol
      }
      base.extend(ClassMethods)

      TracePoint.trace(:end) do |t|
        if base == t.self
          base.validate
          t.disable
        end
      end
    end

    # methods to register events
    module ClassMethods
      attr_reader :events

      # TODO: coordinate server connection name with dev ops
      def publish(event)
        event_key = publisher_key if protocol == :http
        event_key ||= event.name.split('.').last
        publish_operation_name = publish_operation_name_for(event_key)

        logger.debug "Publisher#publish publish_operation_name: #{publish_operation_name}"
        publish_operation = find_publish_operation_for(publish_operation_name)
        payload = event.message&.payload || event.payload
        headers = event.message&.headers || event.headers

        publish_operation.call(payload, {headers: headers})
      end

      def channel_name
        publisher_key.to_sym
      end

      def delimiter
        EventSource.delimiter(protocol)
      end

      def register_event(event_key, options = {})
        @events = {} unless defined?(@events)
        @events[event_key] = options
        self
      end

      # Validates given protocol has publish operation defined for publish operation name
      def validate
        return unless events

        events.each_key do |event_name|
          publish_operation_name = publish_operation_name_for(event_name)

          logger.debug "#{self}#validate find publish operation for: #{publish_operation_name}"
          publish_operation = find_publish_operation_for(publish_operation_name)

          if publish_operation
            logger.debug "#{self}#validate found publish operation for: #{publish_operation_name}"
          else
            logger.error "\n *******\n #{self}#validate unable to find publish operation for: #{publish_operation_name}\n *******"
          end
        end
      end

      def publish_operation_name_for(event_name)
        publish_operation_name = publisher_key if publisher_key == event_name
        publish_operation_name || [publisher_key, event_name].join(delimiter)
      end

      def find_publish_operation_for(publish_operation_name)
        connection_manager.find_publish_operation({
                                                    protocol: protocol, publish_operation_name: publish_operation_name
                                                  })
      end

      def connection_manager
        EventSource::ConnectionManager.instance
      end

      def publisher_key
        EventSource::Publisher.publisher_container[self][:publisher_key]
      end

      def protocol
        EventSource::Publisher.publisher_container[self][:protocol]
      end

      def logger
        EventSourceLogger.new.logger
      end
    end
  end
end
