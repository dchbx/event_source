# frozen_string_literal: true

module EventSource
  # An independent communication pathway within a {EventSource::Connection}
  #   for transmitting and recieving messages.  A Connection may have
  #   one or more Channels
  class Channel
    include EventSource::Logging

    # @attr_reader [Hash] subscribe_operations The collection of registered
    #   {EventSource::SubscribOperation} on this Connection
    # @attr_reader [Hash] publish_operations The collection of registered
    #   {EventSource::Publishperation} on this Connection
    # @attr_reader [Hash] consumers
    # @attr_reader [Object] channel_proxy The protocol adapter instance for this DSL
    attr_reader :subscribe_operations,
                :publish_operations,
                :consumers,
                :channel_proxy,
                :connection

    # The list of DSL methods that a protocol's injected channel proxy class
    # must respond to
    ADAPTER_METHODS = %i[
      subscribe_operations
      publish_operations
      add_subscribe_operation
      add_publish_operation
      find_publish_operation_by_name
      find_subscribe_operation_by_name
      name
      status
      close
    ].freeze

    # @param channel_proxy [Object] an instance of the Connection protcol's
    #  channel adapter that responds to this Channel DSL
    # @param async_api_channel_item [Hash] configuration values in the form of
    #   a {EventSource::AsyncApi::ChannelItem}
    # @return [Object]
    def initialize(connection, channel_proxy, async_api_channel_item)
      @connection = connection
      @channel_proxy = channel_proxy
      @publish_operations = {}
      @subscribe_operations = {}

      add_publish_operation(async_api_channel_item)
      add_subscribe_operation(async_api_channel_item)
    end

    # The unique identifier for this Channel instance
    # @return [String] name
    def name
      @channel_proxy.name
    end

    # This Channel instance's currrent state. Values for states vary by
    #   protcol type
    # @return [Symbol] status
    def status
      @channel_proxy.status
    end

    # Stop all communication using this Channel instance
    def close
      @channel_proxy.close
    end

    # Create and register an operation to broadcast messages
    # @param async_api_channel_item [Hash] configuration values in the form of
    #   an {EventSource::AsyncApi::ChannelItem}
    # @return [EventSource::PublishOperation]
    def add_publish_operation(async_api_channel_item)
      return false unless async_api_channel_item.publish
      publish_proxy =
        @channel_proxy.add_publish_operation(async_api_channel_item)
      return false unless publish_proxy

      @channel_proxy.create_exchange_to_exchange_bindings(publish_proxy) if @connection.protocol == :amqp
      operation_id = async_api_channel_item.publish.operationId

      logger.info "Adding Publish Operation:  #{operation_id}"
      @publish_operations[operation_id] =
        EventSource::PublishOperation.new(
          self,
          publish_proxy,
          async_api_channel_item.publish
        )
      logger.info "  Publish Operation Added: #{operation_id}"
    end

    # Create and register an operation to receive messages broadcast by a PublishOperation.
    # PublishOperation names must be unique across all Channels.
    # @param async_api_channel_item [Hash] configuration values in the form of
    #   an {EventSource::AsyncApi::ChannelItem}
    # @return [EventSource::SubscribeOperation]
    def add_subscribe_operation(async_api_channel_item)
      return false unless async_api_channel_item.subscribe

      subscribe_proxy =
        @channel_proxy.add_subscribe_operation(async_api_channel_item)

      operation_id = async_api_channel_item.subscribe.operationId
      logger.info "Adding Subscribe Operation:  #{operation_id}"
      @subscribe_operations[operation_id] =
        EventSource::SubscribeOperation.new(
          self,
          subscribe_proxy,
          async_api_channel_item.subscribe
        )
      logger.info "  Subscribe Operation Added: #{operation_id}"
    end

    def cancel_consumers
      subscribe_operations.each_value do |sub_op|
        subject = sub_op.subject
        subject.cancel_consumers! if subject.respond_to?(:cancel_consumers!)
      end
    end
  end
end
