# frozen_string_literal: true

require 'spec_helper'
require 'config_helper'

RSpec.describe EventSource::ConnectionManager do

  before(:all) do
    described_class.instance.drop_connections_for(:amqp)
    described_class.instance.drop_connections_for(:http)
  end

  context 'A ConnectionManager Singleton instance' do
    let(:connection_manager) { described_class.instance }

    it 'should successfully initialize if there are no other ConnectionManagers are present' do
      expect(connection_manager).to be_an_instance_of described_class
    end

    it 'initializing another ConnectionManager will reference the existing instance' do
      expect(described_class.instance).to eq connection_manager
    end

    context 'and no connections are present' do

      before { connection_manager.drop_connections_for(:amqp) }

      it 'the connnections should be empty' do
        expect(connection_manager.connections).to be_empty
      end
      context 'and an unknown protocol connection is added' do
        let(:invalid_protocol) { ':xxxx'  }
        let(:url) { 'amqp://localhost:5672/' }
        let(:protocol_version) { '0.9.1' }
        let(:description) { 'Development RabbitMQ Server' }

        let(:invalid_server) do
          {
            url: url,
            protocol: invalid_protocol,
            protocol_version: protocol_version,
            description: description
          }
        end

        it 'should raise an error' do
          expect do
            connection_manager.add_connection(invalid_server)
          end.to raise_error EventSource::Protocols::Amqp::Error::UnknownConnectionProtocolError
        end
      end

      context 'and a known protocol connnection is added' do
        let(:protocol) { :amqp }
        let(:url) { 'amqp://localhost:5672/' }
        let(:protocol_version) { '0.9.1' }
        let(:description) { 'Development RabbitMQ Server' }

        let(:my_server) do
          {
            ref: url,
            url: url,
            protocol: protocol,
            protocol_version: protocol_version,
            description: description
          }
        end
        it 'should add a new connection' do
          expect(
            connection_manager.add_connection(my_server)
          ).to be_an_instance_of EventSource::Connection
        end

        context 'and connections are present' do
          let(:connection_url) { 'amqp://localhost:5672/' }

          before { connection_manager.add_connection(my_server) }

          it 'should have a connection' do
            expect(
              connection_manager.connections[connection_url]
            ).to be_an_instance_of EventSource::Connection
          end

          context 'and an existing connection is dropped' do
            it 'should close and remove the connection' do
              expect(
                connection_manager.drop_connection(connection_url)
              ).to eq Hash.new
            end
          end

          context '.cancel_consumers_for' do
            let(:connection) { connection_manager.connections[connection_url] }

            let(:async_api_file) do
              Pathname.pwd.join('spec', 'support', 'asyncapi', 'polypress_amqp.yml')
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
              connection.start unless connection.active?
              connection.add_channels(async_api_channels)
              channel.subscribe_operations.values.each do |sub_op|
                subscriber_klass = double('SubscriberKlass')
                sub_op.subscribe(subscriber_klass)
              end
            end

            after { connection.disconnect if connection.active? }

            context 'when inflight messages are present' do
              before do
                allow(EventSource).to receive(:inflight_messages_count).and_return(5)
              end

              it 'waits for timeout' do
                expect(channel).to receive(:cancel_consumers).and_call_original
                connection_manager.cancel_consumers_for(protocol, timeout: 1)
              end
            end

            context 'when inflight messages are draining' do
              before do
                allow(EventSource).to receive(:inflight_messages_count).and_return(1, 0)
              end

              it 'waits for drain' do
                expect(channel).to receive(:cancel_consumers).and_call_original
                connection_manager.cancel_consumers_for(protocol, timeout: 5)
              end
            end

            context 'when no inflight messages are present' do
              before do
                allow(EventSource).to receive(:inflight_messages_count).and_return(0)
              end

              it 'cancels AMQP consumers on each channel without waiting' do
                expect(channel).to receive(:cancel_consumers).and_call_original
                connection_manager.cancel_consumers_for(protocol, timeout: 1)
              end
            end
          end
        end
      end
    end

    context '.find_publish_operation' do

      let(:params) { { protocol: :amqp, publish_operation_name: 'on_my_app.polypress.document_builder' }}
      let(:connection) { double }
      let(:operation) { double }

      context 'when connection exists with given operation' do
        before do
          allow(connection_manager).to receive(:find_connection).with(params).and_return(connection)
          allow(connection).to receive(:find_publish_operation_by_name).and_return(operation)
        end

        it 'should log connection found message' do
          connection_manager.find_publish_operation(params)

          expect(@log_output.readline).to match(/find publish operation with #{params}/)
          expect(@log_output.readline).to match(/found connection for #{params}/)
        end
      end

      context 'when connection not exists with given operation' do
        before do
          allow(connection_manager).to receive(:find_connection).with(params).and_return(nil)
        end

        it 'should log error' do
          connection_manager.find_publish_operation(params)

          expect(@log_output.readline).to match(/find publish operation with #{params}/)
          expect(@log_output.readline).to match(/Unable find connection for publish operation: #{params}/)
        end
      end
    end

    context '.find_susbcribe_operation' do

      let(:params) { { protocol: :amqp, subscribe_operation_name: 'on_my_app.polypress.document_builder' }}
      let(:connection) { double }
      let(:operation) { double }

      context 'when connection exists with given operation' do
        before do
          allow(connection_manager).to receive(:find_connection).with(params).and_return(connection)
          allow(connection).to receive(:find_subscribe_operation_by_name).and_return(operation)
        end

        it 'should log connection found message' do
          connection_manager.find_subscribe_operation(params)

          expect(@log_output.readline).to match(/find subscribe operation with #{params}/)
          expect(@log_output.readline).to match(/found connection for #{params}/)
        end
      end

      context 'when connection not exists with given operation' do
        before do
          allow(connection_manager).to receive(:find_connection).with(params).and_return(nil)
        end

        it 'should log error' do
          connection_manager.find_subscribe_operation(params)

          expect(@log_output.readline).to match(/find subscribe operation with #{params}/)
          expect(@log_output.readline).to match(/Unable find connection for subscribe operation: #{params}/)
        end
      end
    end

    context 'when no connections are present
    - .cancel_consumers_for' do
      let(:protocol) { :amqp }
      let(:connection) { instance_double('EventSource::Connection', protocol: protocol, channels: { default: channel }) }
      let(:channel) { instance_double('EventSource::Channel') }

      before do
        allow(EventSource).to receive(:inflight_messages_count).and_return(0)
      end

      context 'does not raise error' do
        before do
          allow(connection_manager).to receive(:connections_for).with(protocol).and_return([])
          allow(connection_manager).to receive(:wait_for_connections_to_drain)
        end

        it 'and still calls drain helper' do
          expect do
            connection_manager.cancel_consumers_for(protocol, timeout: 1)
          end.not_to raise_error

          expect(connection_manager).to have_received(:wait_for_connections_to_drain).with([], 1)
        end
      end
    end
  end
end
