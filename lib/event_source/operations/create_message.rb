# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module EventSource
  module Operations
    # create message
    class CreateMessage
      include Dry::Monads[:result, :do]

      def call(params)
        values = yield build(params)
        message = yield create(values)

        Success(message)
      end

      private

      def build(params)
        result =
          ::EventSource::AsyncApi::Contracts::MessageContract.new.call(params)

        result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
      end

      def create(values)
        Success(EventSource::AsyncApi::Message.new(values))
      end
    end
  end
end
