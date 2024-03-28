# frozen_string_literal: true

module EventSource
  module AsyncApi
    # The mechanism by which information is exchanged via a channel between servers and applications.
    # A message must contain a payload and may also contain headers. The headers may be subdivided
    # into protocol-defined headers and header properties defined by the application which can
    # act as supporting metadata.
    #
    # The payload contains the data, defined by the application, which must be serialized into a
    # format (JSON, XML, Avro, binary, etc.).
    #
    # Since a message is a generic mechanism, it can support multiple interaction patterns such
    # as event, command, request, or response.
    #
    # Describes a message received on a given channel and operation
    class Message < Dry::Struct
      transform_keys(&:to_sym)

      # @!attribute [r] headers
      # Schema definition of the application headers. Schema must be of type "object".
      # It must not define the protocol headers.
      # @return [Types::Any]
      attribute :headers, Types::Any.meta(omittable: true)

      # @!attribute [r] payload
      # Definition of the message payload. It can be of any type but defaults to Schema object
      # @return [Types::Any]
      attribute :payload, Types::Any.meta(omittable: true)

      # @!attribute [r] schema_format
      # A string containing the name of the schema format used to define the message payload.
      # If omitted, implementations should parse the payload as a Schema object. Check out the
      # supported schema formats table for more information. Custom values are allowed but
      # their implementation is OPTIONAL. A custom value must not refer to one of the schema formats
      # listed in the table.
      # @return [String]
      attribute :schema_format, Types::String.meta(omittable: true)

      # @!attribute [r] content_type
      # The content type to use when encoding/decoding a message's payload. The value must be a
      # specific media type (e.g. application/json). When omitted, the value must be the one specified
      # on the default_content_type field
      # @return [String]
      attribute :contentType, Types::String.meta(omittable: true)

      # @!attribute [r] name
      # A machine-friendly name for the message
      # @return [String]
      attribute :name, Types::String.meta(omittable: true)

      # @!attribute [r] title
      # A human-friendly title for the message
      # @return [String]
      attribute :title, Types::String.meta(omittable: true)

      # @!attribute [r] summary
      # A short summary of what the message is about
      # @return [String]
      attribute :summary, Types::String.meta(omittable: true)

      # @!attribute [r] description
      # A verbose explanation of the message. CommonMark syntax can be used for rich text representation
      # @return [String]
      attribute :description, Types::String.meta(omittable: true)

      # @!attribute [r] tags
      # A list of tags for API documentation control. Tags can be used for logical grouping of messages
      # @return [Array<Tag>]
      attribute :tags, Types::Array.of(Tag).meta(omittable: true)

      # @!attribute [r] description
      # Additional external documentation for this message
      # @return [ExternalDocumentation]
      attribute :external_docs, ExternalDocumentation.meta(omittable: true)

      # @!attribute [r] bindings
      # Map where the keys describe the name of the protocol and the values describe protocol-specific
      # definitions for the message
      # @return [Hash]
      attribute :bindings, Types::Hash.meta(omittable: true)

      # @!attribute [r] examples
      # An array with examples of valid message objects
      # @return [Hash]
      attribute :examples, Types::Array.of(Hash).meta(omittable: true)

      # @!attribute [r] traits
      # A list of traits to apply to the message object. Traits must be merged into the message object
      # using the JSON Merge Patch algorithm in the same order they are defined here. The resulting
      # object must be a valid Message Object
      # @return [Array<MessageTrait>]
      attribute :traits, Types::Array.of(MessageTrait).meta(omittable: true)
    end
  end
end
