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
      # @param payload [Any] the payload to encode;
      #
      # @return [Dry::Monads::Success<String>] if encoding is successful
      # @return [Dry::Monads::Failure<String>] if an error occurs (e.g., invalid MIME type, payload type, or encoding failure)
      def call(mime_type, payload)
        mime_type = yield validate(mime_type)
        encoded_data = yield encode(mime_type, payload)

        Success(encoded_data)
      end

      private

      # Validates theMIME type before encoding.
      # Ensures the MIME type is supported
      #
      # @param mime_type [String] the MIME type for encoding
      #
      # @return [Dry::Monads::Success<String>] if the payload and MIME type are valid
      # @return [Dry::Monads::Failure<String>] if the MIME type is unsupported or the payload is invalid
      def validate(mime_type)
        unless MIME_TYPES.include?(mime_type.to_s)
          return Failure("Invalid MIME type '#{mime_type}'. Supported types are: #{MIME_TYPES.join(', ')}.")
        end

        Success(mime_type.to_s)
      end

      # Encodes the payload based on the MIME type.
      # For 'application/zlib', compresses the payload using Zlib.
      # Logs the original and encoded payload sizes for debugging.
      #
      # @param data [String] the JSON stringified payload to encode
      # @param mime_type [String] the MIME type for encoding
      #
      # @return [Dry::Monads::Success<String>] if encoding is successful
      # @return [Dry::Monads::Failure<String>] if encoding fails
      def encode(mime_type, payload)
        case mime_type
        when 'application/zlib'
          json_payload = payload.to_json
          encoded_data = Zlib.deflate(json_payload)
          log_encoding_details(mime_type, json_payload, encoded_data)
        when 'application/json'
          encoded_data = payload.to_json
        end

        Success(encoded_data || payload)
      rescue JSON::GeneratorError => e
        Failure("Failed to encode payload to JSON: #{e.message}")
      rescue Zlib::Error => e
        Failure("Failed to compress payload using Zlib: #{e.message}")
      rescue StandardError => e
        Failure("Unexpected error during encoding: #{e.message}")
      end

      # Logs details of the encoding process.
      def log_encoding_details(mime_type, payload, encoded_data)
        logger.debug "*" * 80
        logger.debug "Starting payload encoding for MIME type: '#{mime_type}'"
        logger.debug "Original payload size: #{data_size_in_kb(payload)} KB"
        logger.debug "Encoded payload size: #{data_size_in_kb(encoded_data)} KB"
        logger.debug "*" * 80
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
