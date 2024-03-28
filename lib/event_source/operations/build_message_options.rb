# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"
require "securerandom"

module EventSource
  module Operations
    # extract message options
    class BuildMessageOptions
      include Dry::Monads[:result, :do]

      def call(params)
        headers = yield build_headers(params)
        payload = yield build_payload(params)
        headers = yield append_account_details(headers)

        Success(headers: headers, payload: payload)
      end

      private

      def build_headers(params)
        headers = params[:headers]&.symbolize_keys || {}
        headers[:correlation_id] ||= SecureRandom.uuid
        headers[:message_id] ||= SecureRandom.uuid
        headers[:event_name] ||= params[:event_name]
        headers[:event_time] = headers[:event_time]&.utc

        Success(headers)
      end

      def build_payload(params)
        payload = params[:payload]&.symbolize_keys || {}

        Success(payload)
      end

      def append_account_details(headers)
        output = FetchSession.new.call
        return output unless output.success?

        session, current_user, system_account = output.value!
        account = {}

        if session.present? && current_user.present?
          account[:session] = session&.symbolize_keys
          account[:id] = current_user&.id&.to_s
        else
          account[:id] = system_account&.id&.to_s
        end
        headers[:account] = account

        Success(headers)
      end
    end
  end
end
