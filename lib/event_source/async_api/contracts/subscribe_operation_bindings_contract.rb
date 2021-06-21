# frozen_string_literal: true

require "event_source/protocols/amqp/contracts/subscribe_operation_binding_contract"

module EventSource
  module AsyncApi
    module Contracts
      # Schema and validation rules for publish bindings
      class SubscribeOperationBindingsContract < Contract
        params do
          optional(:http).hash
          optional(:amqp).value(::EventSource::Protocols::Amqp::Contracts::SubscribeOperationBindingContract.params)
        end
      end
    end
  end
end
