# frozen_string_literal: true

module EventSource
  module Protocols
    module Amqp
      module Contracts
        class OperationBindingContract < Contract
          params do
            optional(:expiration).value(
              EventSource::AsyncApi::Types::PositiveInteger
            )
            optional(:user_id).maybe(:string)
            optional(:cc).maybe(EventSource::AsyncApi::Types::RoutingKeyKinds)
            optional(:priority).maybe(:integer)
            optional(:delivery_mode).maybe(
              EventSource::AsyncApi::Types::MessageDeliveryModeKind
            )
            optional(:mandatory).maybe(:bool)
            optional(:bcc).maybe(EventSource::AsyncApi::Types::RoutingKeyKinds)
            optional(:reply_to).maybe(EventSource::AsyncApi::Types::QueueName)
            optional(:timestamp).maybe(:bool)
            optional(:ack).maybe(:bool)
            optional(:binding_version).maybe(EventSource::AsyncApi::Types::AmqpBindingVersionKind)
          end
        end
      end
    end
  end
end
