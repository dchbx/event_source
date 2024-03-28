# frozen_string_literal: true

module EventSource
  # Generate and forwared a notification that something has happened in the system
  class Event
    extend Dry::Initializer

    # @attr_reader [Array<String>] attribute_keys optional list of attributes that must be included in { Payload }
    # @attr_reader [String] publisher_path namespaced key indicating the class that registers event for publishing
    # @attr_reader [String] payload attribute/value pairs for the message that accompanies the event
    attr_reader :attribute_keys, :publisher_path, :payload, :headers, :metadata, :message

    HeaderDefaults = {
      version: '3.0',
      occurred_at: DateTime.now
      # correlation_id: 'ADD CorrID Snowflake GUID',
      # command_name: '',
      # entity_kind: ''
    }.freeze

    def initialize(options = {})
      @attribute_keys = klass_var_for(:attribute_keys) || []
      @payload = {}

      send(:payload=, options[:attributes] || {})
      send(:headers=, options[:headers] || {})

      @publisher_path = klass_var_for(:publisher_path) || nil
      build_message(options) if headers.delete(:build_message)

      if @publisher_path.eql?(nil)
        raise EventSource::Error::PublisherKeyMissing,
              "add 'publisher_path' to #{self.class.name}"
      end
    end

    def build_message(options)
      @message = EventSource::Message.new(
          headers: options[:headers],
          payload: options[:attributes],
          event_name: name
        )
    end

    # Set payload
    # @overload payload=(payload)
    #   @param [Hash] payload New payload
    #   @return [Event] A copy of the event with the provided payload
    def payload=(values)
      raise ArgumentError, 'payload must be a hash' unless values.instance_of?(Hash)

      @payload = values
    end

    def headers=(values)
      raise ArgumentError, 'headers must be a hash' unless values.instance_of?(Hash)

      @headers = values
    end

    # Verify this instance is complete and may be published
    # @return [Boolean]
    def valid?
      event_errors.empty?
    end

    # Send the event instance to its producer so that it may be accessed by subscribers
    # @raise [EventSource::Error::AttributesInvalid]
    def publish
      raise EventSource::Error::AttributesInvalid, @event_errors unless valid?

      publisher_klass = publisher_klass(publisher_path)
      publisher_klass.publish(self)
    end

    def publisher_klass(key)
      key.split('.').map(&:camelize).join('::').constantize
    end

    def name
      return @name if defined?(@name)
      @name = self.class.name.gsub('::', '.').underscore
    end

    def event_errors
      @event_errors ||= []
    end

    # Coerce an event to a hash
    # @return [Hash]
    def to_h
      @payload
    end

    # Get payload attribute values
    # @param [String, Symbol] name
    def [](name)
      payload[name]
    end

    # Set payload attribute values
    def []=(name, value)
      @payload.merge!({ "#{name}": value })
      validate_attribute_presence
      self[name]
    end

    # Class methods
    class << self
      def publisher_path(value = nil)
        set_instance_variable_for(:publisher_path, value)
      end

      def contract_key(value = nil)
        set_instance_variable_for(:contract_key, value)
      end

      def entity_key(value = nil)
        set_instance_variable_for(:entity_key, value)
      end

      def attribute_keys(*keys)
        value = (keys.empty? ? nil : keys.map(&:to_sym))
        set_instance_variable_for(:attribute_keys, value)
      end

      def set_instance_variable_for(element, value)
        if value.nil?
          return instance_variable_get("@#{element}") if instance_variable_defined?("@#{element}")
        else
          instance_variable_set("@#{element}", value)
        end
      end
    end

    private

    def validate_attribute_presence
      return unless attribute_keys.present?

      gapped_keys = attribute_keys - payload.keys
      @event_errors = []
      event_errors.push("missing required keys: #{gapped_keys}") unless gapped_keys.empty?
    end

    def constant_for(value)
      constant_name = value.split('.').each(&:upcase!).join('_')
      return constant_name.constantize if Object.const_defined?(constant_name)
      raise EventSource::Error::ConstantNotDefined,
            "Constant not defined for: '#{constant_name}'"
    end

    def klass_var_for(var_name)
      self.class.send(var_name) if self.class.respond_to? var_name
    end
  end
end
