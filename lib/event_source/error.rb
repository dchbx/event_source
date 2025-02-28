# frozen_string_literal: true

module EventSource
  module Error
    # @api private
    module ErrorInitializer
      attr_reader :original

      def initialize(msg, original = $ERROR_INFO)
        super(msg)
        @original = original
      end
    end

    # @api public
    class Error < StandardError
      include ErrorInitializer
    end

    AttributesInvalid = Class.new(Error)
    ConstantNotDefined = Class.new(Error)
    ContractNotFound = Class.new(Error)
    EventNameUndefined = Class.new(Error)
    FileAccessError = Class.new(Error)
    InvalidChannelsResourceError = Class.new(Error)
    PublisherAlreadyRegisteredError = Class.new(Error)
    PublisherKeyMissing = Class.new(Error)
    PublisherNotFound = Class.new(Error)
    RegisteredEventNotFound = Class.new(Error)
    SubscriberNotFound = Class.new(Error)
    ConnectionNotFound = Class.new(Error)
    ServerConfigurationNotFound = Class.new(Error)
    ServerConfigurationInvalid = Class.new(Error)
    MessageBuildError = Class.new(Error)
    PayloadEncodeError = Class.new(Error)
    PayloadDecodeError = Class.new(Error)
  end
end
