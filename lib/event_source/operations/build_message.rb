# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module EventSource
  module Operations
    # create message
    class BuildMessage
      include Dry::Monads[:result, :do]

      def call(params)
        values = yield build_options(params)
        message = yield create_message(values)

        Success(message)
      end

      private

      def build_options(params)
        result = BuildMessageOptions.new.call(params)
        result.success? ? result : Failure(result.errors.to_h)
      end

      def create_message(values)
        CreateMessage.new.call(values)
      end
    end
  end
end
