# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module EventSource
  module Operations
    # Operation for decoding payloads, including decompression using Zlib.
    class MimeDecode
      include Dry::Monads[:result, :do]
      include EventSource::Logging

      # Supported MIME types for decoding.
      MIME_TYPES = %w[application/zlib application/json].freeze

      # Decodes the payload based on the specified MIME type.
      # For example, decompresses the payload using Zlib for 'application/zlib'.
      #
      # @param mime_type [String] the MIME type of the payload (e.g., 'application/zlib', 'application/json')
      # @param payload [String] the encoded payload to decode
      #
      # @return [Dry::Monads::Success<String>] if decoding is successful
      # @return [Dry::Monads::Failure<String>] if an error occurs (e.g., invalid MIME type, decoding failure)
      def call(mime_type, payload)
        valid_payload, mime_type = yield validate_payload(payload, mime_type.to_s)
        decoded_data = yield decode(valid_payload, mime_type)

        Success(decoded_data)
      end

      private

      # Validates the payload based on the MIME type.
      # Ensures the payload is binary-encoded for 'application/zlib' MIME type.
      #
      # @param payload [String] the payload to validate
      # @param mime_type [String] the MIME type of the payload
      #
      # @return [Dry::Monads::Success<String>] if the payload is valid
      # @return [Dry::Monads::Failure<String>] if the payload is invalid
      def validate_payload(payload, mime_type)
        unless MIME_TYPES.include?(mime_type)
          return Failure("Invalid MIME type '#{mime_type}'. Supported types are: #{MIME_TYPES.join(', ')}.")
        end

        # Allow JSON string payloads to pass validation to avoid processing failures
        # for existing JSON messages in the queue. These messages may have been queued
        # with the wrong MIME type ('application/zlib') but are still valid JSON.
        if mime_type == 'application/zlib'
          return Failure("Payload must be binary-encoded for MIME type 'application/zlib'.") unless binary_payload?(payload) || valid_json_string?(payload)
        end

        Success([payload, mime_type])
      end

      # Decodes the payload based on the specified MIME type.
      # For 'application/zlib', it attempts to decompress the payload using Zlib.
      # If decompression fails due to an error, the original payload is returned unmodified.
      #
      # @param payload [String] the payload to decode
      # @param mime_type [String] the MIME type of the payload
      #
      # @return [Dry::Monads::Success<String>] if decoding is successful or if the MIME type is not 'application/zlib'.
      # @return [Dry::Monads::Success<String>] if decompression fails, returning the original payload without modification.
      #
      # @note If the MIME type is 'application/zlib' and decompression fails, the original payload is returned as is, and no error is raised.
      def decode(payload, mime_type)
        return Success(payload) unless mime_type == 'application/zlib'

        begin
          decoded_data = Zlib.inflate(payload)
          Success(decoded_data)
        rescue Zlib::Error => e
          logger.error "Zlib errored while inflating payload: #{payload} \n with #{e.class}: #{e.message}, \n returning original payload."
          Success(payload)
        end
      end

      # Checks whether the payload is binary-encoded.
      #
      # @param payload [String] the payload to check
      #
      # @return [Boolean] true if the payload is binary-encoded, false otherwise
      def binary_payload?(payload)
        return false unless payload.respond_to?(:encoding)

        payload.encoding == Encoding::BINARY
      end

      def valid_json_string?(data)
        data.is_a?(String) && JSON.parse(data)
        true
      rescue JSON::ParserError
        false
      end      
    end
  end
end
