# frozen_string_literal: true

require_relative 'rails_helper'

RSpec.describe EventSource::Railtie do
  before do
    @original_auto_shutdown = EventSource.config.auto_shutdown
    EventSource.config.auto_shutdown = auto_shutdown_enabled
    @at_exit_handler = nil
    allow_any_instance_of(Object).to receive(:at_exit) do |_, &blk|
      @at_exit_handler = blk
    end
    initializer = Rails.application.initializers.find { |i| i.name == 'event_source.boot' }
    initializer.run(Rails.application)
  end

  context '.auto_shutdown' do
    let(:protocol) { :amqp }
    let(:url) { 'amqp://localhost:5672/' }
    let(:protocol_version) { '0.9.1' }
    let(:description) { 'Development RabbitMQ Server' }
    let(:server_config) do
      {
        ref: url,
        url: url,
        protocol: protocol,
        protocol_version: protocol_version,
        description: description
      }
    end

    let(:connection_manager) { EventSource::ConnectionManager.instance }
    let(:connection) do
      connection_manager.add_connection(server_config)
      connection_manager.connections_for(:amqp).first
    end

    let(:async_api_file) do
      Pathname.new(__dir__).join('..', '..', 'support', 'asyncapi', 'polypress_amqp.yml').expand_path
    end

    let(:async_api_channels) do
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
        .new
        .call(path: async_api_file)
        .success
        .channels
    end

    let(:channel) do
      connection.channels[:'on_polypress.magi_medicaid.mitc.eligibilities']
    end

    before do
      connection_manager.drop_connections_for(:amqp)
      connection_manager.drop_connections_for(:http)
      connection.start unless connection.active?
      connection.add_channels(async_api_channels)

      channel.subscribe_operations.each_value do |subscribe_operation|
        subscriber_klass = double('SubscriberKlass')
        subscribe_operation.subscribe(subscriber_klass)
      end

      @original_timeouts = EventSource.config.shutdown_timeouts
      EventSource.config.shutdown_timeouts = { amqp_drain: 2 }
      allow(EventSource).to receive(:inflight_messages_count).and_return(0)
    end

    after do
      EventSource.config.shutdown_timeouts = @original_timeouts
      EventSource.config.auto_shutdown = @original_auto_shutdown
    end

    context 'when auto_shutdown is enabled' do
      let(:auto_shutdown_enabled) { true }

      it 'cancels AMQP consumers and drops AMQP connections on shutdown' do
        expect(connection_manager.connections_for(:amqp)).not_to be_empty
        expect(connection.channels).not_to be_empty
        expect(channel.subscribe_operations.values.first.subject.consumers).not_to be_empty
        expect(@at_exit_handler).not_to be_nil
        @at_exit_handler.call

        expect(connection_manager.connections_for(:amqp)).to be_empty
      end
    end

    context 'when auto_shutdown is disabled' do
      let(:auto_shutdown_enabled) { false }

      it 'does not register at_exit handler' do
        expect(connection_manager.connections_for(:amqp)).not_to be_empty
      end
    end
  end
end
