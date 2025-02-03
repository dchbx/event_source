# frozen_string_literal: true

module EventSource
  # Publish {EventSource::Event} messages
  class PublishOperation
    include EventSource::Logging

    # @attr_reader [EventSource::Channel] channel the channel instance used by
    #   this PublishOperation
    # @attr_reader [Object] subject instance of the protocol's publish class
    # @attr_reader [String] name unique identifier for this operation
    attr_reader :channel, :subject, :name

    ADAPTER_METHODS = %i[call name].freeze

    # @param [EventSource::Channel] channel the protocol's communication channel
    # @param [Object] publish_proxy instance of the protocol's publisher class
    # @param [EventSource::AsyncApi::PublishOperation] async_api_publish_operation
    #   coniguration options for this operation
    def initialize(channel, publish_proxy, async_api_publish_operation)
      @channel = channel
      @subject = publish_proxy
      @async_api_publish_operation = async_api_publish_operation
      @name = async_api_publish_operation[:operationId]
    end

    # Publish an {EventSource::Event} message
    # @example
    #   #publish("Message", :headers => { })
    def call(payload, options = {})
      payload = encode_payload(payload)
      @subject.publish(
        payload: payload,
        publish_bindings: @async_api_publish_operation[:bindings],
        headers: options[:headers] || {}
      )
    end

    # Encodes the given payload based on the `contentEncoding` specified in the AsyncAPI *_publish.yml message bindings.
    #
    # For example, if `contentEncoding` is set to `application/zlib`, the payload will be compressed using zlib.
    # If no `contentEncoding` is provided, the payload will be returned as-is without modification.
    #
    # Note:
    # - Encoding is not needed for the HTTP protocol, as encoding is handled at the server level.
    # - For other protocols like AMQP, encoding is supported to ensure proper message transmission.
    #
    # @param payload [String, Hash] The payload to be encoded.
    # @return [String] The encoded payload, or the original payload if no encoding is specified.
    # @raise [EventSource::Error::PayloadEncodeError] if the encoding process fails.
    def encode_payload(payload)
      encoding = determine_encoding
      return payload unless encoding

      output = EventSource::Operations::MimeEncode.new.call(encoding, payload)
      if output.success?
        output.value!
      else
        logger.error "Failed to decompress message \n  due to: #{output.failure}"
        raise EventSource::Error::PayloadEncodeError, output.failure
      end
    end

    # Determines the encoding for the payload based on message bindings or protocol defaults.
    # - If message bindings are present, uses the 'contentEncoding' value from the bindings.
    # - If no message bindings are present and the protocol is AMQP, uses the default encoding for the AMQP protocol. Other protocols return nil.
    def determine_encoding
      message_bindings = @async_api_publish_operation.message&.dig('bindings')
      return message_bindings.first[1]['contentEncoding'] if message_bindings.present?

      amqp_protocol? ? "#{subject.class}::DefaultMimeType".constantize : nil
    end

    def amqp_protocol?
      subject.is_a?(EventSource::Protocols::Amqp::BunnyExchangeProxy)
    end
  end
end
