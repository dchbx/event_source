# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module EventSource
  module Operations
    # Operation for encoding payloads into specified MIME types.
    # For example, it supports compression using Zlib for 'application/zlib'.
    class MimeEncode
      include Dry::Monads[:result, :do]
      include EventSource::Logging

      # Supported MIME types for encoding.
      MIME_TYPES = %w[application/zlib application/json].freeze

      # Encodes the given payload into the specified MIME type.
      # For example, compresses the payload using Zlib for 'application/zlib'.
      #
      # @param mime_type [String] the MIME type for encoding (e.g., 'application/zlib', 'application/json')
      # @param payload [String, Hash] the payload to encode; must be a Hash or String
      #
      # @return [Dry::Monads::Success<String>] if encoding is successful
      # @return [Dry::Monads::Failure<String>] if an error occurs (e.g., invalid MIME type, payload type, or encoding failure)
      def call(mime_type, payload)
        json_payload = yield validate_payload(payload, mime_type)
        encoded_data = yield encode(json_payload, mime_type)

        Success(encoded_data)
      end

      private

      # Validates the payload and MIME type before encoding.
      # Ensures the MIME type is supported and the payload is either a Hash or a String.
      #
      # @param payload [String, Hash] the payload to validate
      # @param mime_type [String] the MIME type for encoding
      #
      # @return [Dry::Monads::Success<String>] if the payload and MIME type are valid
      # @return [Dry::Monads::Failure<String>] if the MIME type is unsupported or the payload is invalid
      def validate_payload(payload, mime_type)
        unless MIME_TYPES.include?(mime_type.to_s)
          return Failure("Invalid MIME type '#{mime_type}'. Supported types are: #{MIME_TYPES.join(', ')}.")
        end

        unless payload.is_a?(Hash) || payload.is_a?(String)
          return Failure("Invalid payload type. Expected a Hash or String, but received #{payload.class}.")
        end

        Success(payload.is_a?(Hash) ? payload.to_json : payload)
      end

      # Encodes the payload based on the MIME type.
      # For 'application/zlib', compresses the payload using Zlib.
      # Logs the original and encoded payload sizes for debugging.
      #
      # @param json_payload [String] the JSON stringified payload to encode
      # @param mime_type [String] the MIME type for encoding
      #
      # @return [Dry::Monads::Success<String>] if encoding is successful
      # @return [Dry::Monads::Failure<String>] if encoding fails
      def encode(json_payload, mime_type)
        encoded_data = Zlib.deflate(json_payload) if mime_type.to_s == 'application/zlib'

        logger.debug "*" * 80
        logger.debug "Starting payload encoding for MIME type: '#{mime_type}'"
        logger.debug "Original payload size: #{data_size_in_kb(json_payload)} KB"
        logger.debug "Encoded payload size: #{data_size_in_kb(encoded_data)} KB" if encoded_data
        logger.debug "*" * 80

        Success(encoded_data || json_payload)
      rescue Zlib::Error => e
        Failure("Failed to compress payload using Zlib: #{e.message}")
      end

      # Calculates the size of the data in kilobytes (KB).
      #
      # @param data [String] the data whose size is to be calculated
      #
      # @return [Float] the size of the data in KB, rounded to two decimal places
      def data_size_in_kb(data)
        (data.bytesize / 1024.0).round(2)
      end
    end
  end
end
