# frozen_string_literal: true

require "forwardable"

module EventSource
  # Construct async api message object
  class Message
    extend Forwardable

    def initialize(options = {})
      message_options = build_message(options)
      @message = create_message(message_options)
    end

    def_delegators :@message, :payload, :headers

    private

    def build_message(options)
      result = EventSource::Operations::BuildMessageOptions.new.call(options)
      unless result.success?
        raise EventSource::Error::MessageBuildError,
              "unable to build message options due to #{result.failure}"
      end
      result.success
    end

    def create_message(options)
      result = EventSource::Operations::CreateMessage.new.call(options)
      unless result.success?
        raise EventSource::Error::MessageBuildError,
              "unable to create message due to #{result.failure}"
      end
      result.success
    end
  end
end
