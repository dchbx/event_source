# frozen_string_literal: true

# require 'dry/events/publisher'

module EventSource
  # A notification that something has happened in the system
  # @example
  # An Event has the following public API
  #   MyEvent.call(event_key, options)
  #   event = MyEvnet.new(event_key, options:)
  #
  # (attributes:, metadata:, contract_key:)
  #
  #   event.valid? # true or false
  #   event.errors # +> <Dry::Validation::Errors ... >
  #   event.publish # validate and execute the command
  class Event
    extend Dry::Initializer

    HeaderDefaults = {
      version: '3.0',
      occurred_at: DateTime.now
      # correlation_id: 'ADD CorrID Snowflake GUID',
      # command_name: '',
      # entity_kind: ''
    }.freeze

    class << self

      def publisher_key(value = nil)
        set_instance_variable_for(:publisher_key, value)
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

    # @!attribute [r] id
    # @return [Symbol, String] The event identifier
    # attr_accessor :attributes
    attr_reader :attribute_keys,
                :publisher_key,
                :publisher_class,
                :headers,
                :payload

    def initialize(options = {})
      @attribute_keys = klass_var_for(:attribute_keys) || []

      @payload = {}
      send(:payload=, options[:attributes] || {})

      metadata = (options[:metadata] || {}).merge(event_key: event_key)
      @headers = HeaderDefaults.merge(metadata)

      # @publisher_key = klass_var_for(:publisher_key) || nil
      # raise EventSource::Error::PublisherKeyMissing, "add 'publisher_key' to #{self.class.name}" if @publisher_key.eql?(nil)
      # TODO: Verify if needed
      # @publisher_class = constant_for(@publisher_key)
    end

    # Set payload
    # @overload payload=(payload)
    #   @param [Hash] payload New payload
    #   @return [Event] A copy of the event with the provided payload

    def payload=(values)
      raise ArgumentError, 'payload must be a hash' unless values.instance_of?(Hash)

      values.symbolize_keys!

      @payload =
        values.select do |key, _value|
          attribute_keys.empty? || attribute_keys.include?(key)
        end

      validate_attribute_presence
    end

    # @return [Boolean]
    def valid?
      event_errors.empty?
    end

    def publish
      raise EventSource::Error::AttributesInvalid, @event_errors unless valid?
      # EventSource.adapter.enqueue(self)
      EventSource.adapter.publish(event_key, payload)
    end

    def event_key
      return @event_key if defined? @event_key
      @event_key = self.class.name.gsub('::', '.').underscore
    end

    def event_errors
      @event_errors ||= []
    end

    # Coerce an event to a hash
    # @return [Hash]
    def to_h
      @payload
    end

    # Get data from the payload
    # @param [String, Symbol] name
    def [](name)
      payload[name]
    end

    def []=(name, value)
      @payload.merge!({ "#{name}": value })
      validate_attribute_presence
      self[name]
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
      raise EventSource::Error::ConstantNotDefined, "Constant not defined for: '#{constant_name}'"
    end

    def klass_var_for(var_name)
      self.class.send(var_name) if self.class.respond_to? var_name
    end
  end
end
