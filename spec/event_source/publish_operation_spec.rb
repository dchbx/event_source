# frozen_string_literal: true

require 'spec_helper'
require 'event_source/protocols/amqp_protocol'

RSpec.describe EventSource::PublishOperation do
  let(:connection_manager) { EventSource::ConnectionManager.instance }
  let(:server_settings) do
    {
      protocol: :amqp,
      host: 'amqp://localhost',
      vhost: '/',
      port: '5672',
      url: 'amqp://localhost:5672',
      user_name: 'guest',
      password: 'guest'
    }
  end

  let(:connection) { connection_manager.add_connection(server_settings) }

  let(:publish_resource_path) do
    Pathname.pwd.join('spec', 'support', 'asyncapi', 'medicaid_amqp.yml')
  end
  let(:subscribe_resource_path) do
    Pathname.pwd.join('spec', 'support', 'asyncapi', 'polypress_amqp.yml')
  end

  let(:load_publish_resource) do
    publish_resource =
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
      .new
      .call(path: publish_resource_path)
      .success
    connection.add_channels(
      publish_resource.channels
    )
  end

  let(:load_subscribe_resource) do
    subscribe_resource =
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
      .new
      .call(path: subscribe_resource_path)
      .success
    connection.add_channels(
      subscribe_resource.channels
    )
  end

  let(:setup) do
    load_publish_resource
    load_subscribe_resource
  end

  before do
    connection.start unless connection.active?
    setup
  end
  # after { connection.stop if connection.active?}

  let(:subscriber_channel) do
    connection.channels[:'on_polypress.magi_medicaid.mitc.eligibilities']
  end

  let(:publisher_name) do
    channel.publish_operations.values.first.name
  end

  let(:channel) do
    connection.channels.values.first
  end

  let(:publish_operation) do
    connection.find_publish_operation_by_name(publisher_name)
  end

  let(:greeting) { 'hello world!' }

  context 'when headers passed with correlation id' do
    let(:input_headers) do
      {
        :venue => "Stockholm",
        :true_field   => true,
        :false_field  => false,
        :correlation_id => "36126121212"
      }
    end

    let(:bunny_formatted_options) do
        {
          :venue => "Stockholm",
          :true_field   => true,
          :false_field  => false,
        }
    end

    let(:expected_log_message) { "#{bunny_formatted_options.inspect}" }

    it "publish payload along with headers" do
      @log_output.readlines
      publish_operation.call({message: greeting}, {headers: input_headers})
      expect(@log_output.readline).to match(/#{expected_log_message}/)
    end
  end

  context 'when valid asyncapi configurations passed' do

    it 'should set exchanges and queues' do
      expect(connection.channels).to be_present
      expect(connection.channels.first.last.publish_operations).to be_present
      expect(subscriber_channel).to be_present
    end

    it 'should publish a message to an exchange' do
      # expect(publish_operation.subject.subject).to receive(:on_return)
      publish_operation.call(message: greeting)
    end

    it 'should forward the message to a queue bound to the exchange' do
    end
  end

  describe '#encode_payload' do

    let(:channel) { instance_double('EventSource::Channel') }
    let(:publish_proxy) { instance_double('PublishProxy', publish: true) }
    let(:async_api_publish_operation) do
      EventSource::AsyncApi::PublishOperation.new({
        operationId: 'publish_message',
        bindings: { amqp: { key: 'value' } },
        message: {
          'bindings' => { 'amqp' => { 'contentEncoding' => 'application/zlib' } }
        }
      })
    end

    let(:instance) { described_class.new(channel, publish_proxy, async_api_publish_operation) }

    describe '#encode_payload' do
      let(:payload) { 'test_payload' }
      let(:mime_encode_operation) { instance_double(EventSource::Operations::MimeEncode) }

      before do
        allow(EventSource::Operations::MimeEncode).to receive(:new).and_return(mime_encode_operation)
      end

      context 'when there is no message in the async API publish operation' do
        let(:async_api_publish_operation) { EventSource::AsyncApi::PublishOperation.new({ operationId: 'publish_message', bindings: {} }) }

        it 'returns the original payload' do
          expect(instance.encode_payload(payload)).to eq(payload)
        end
      end

      context 'when there is no contentEncoding in the message bindings' do
        let(:async_api_publish_operation) do
          EventSource::AsyncApi::PublishOperation.new({ operationId: 'publish_message', message: { } })
        end

        it 'returns the original payload' do
          expect(instance.encode_payload(payload)).to eq(payload)
        end
      end

      context 'when contentEncoding is provided' do
        context 'when encoding is successful' do
          let(:encoded_payload) { 'encoded_payload' }

          before do
            allow(mime_encode_operation).to receive(:call)
              .with('application/zlib', payload)
              .and_return(Dry::Monads::Success(encoded_payload))
          end

          it 'returns the encoded payload' do
            expect(instance.encode_payload(payload)).to eq(encoded_payload)
          end
        end

        context 'when encoding fails' do
          let(:failure_message) { 'Encoding error' }

          before do
            allow(mime_encode_operation).to receive(:call)
              .with('application/zlib', payload)
              .and_return(Dry::Monads::Failure(failure_message))
          end

          it 'logs the error and raises a PayloadEncodeError' do
            expect(instance.logger).to receive(:error).with("Failed to encode message \n  due to: #{failure_message}")
            expect do
              instance.encode_payload(payload)
            end.to raise_error(EventSource::Error::PayloadEncodeError, failure_message)
          end
        end
      end
    end
  end
end

# RSpec.describe EventSource::PublishOperation do
#   let(:server) do
#     {
#       url: 'amqp://localhost:5672/',
#       protocol: :amqp,
#       protocol_version: '0.9.1',
#       description: 'Development RabbitMQ Server'
#     }
#   end

#   let(:connection_proxy) do
#     EventSource::Protocols::Amqp::BunnyConnectionProxy.new(server)
#   end

#   let(:channel_proxy) do
#     EventSource::Protocols::Amqp::BunnyChannelProxy.new(
#       connection_proxy,
#       channel_item_key,
#       channel_item
#     )
#   end

#   let(:channel_bindings) do
#     {
#       amqp: {
#         is: :routing_key,
#         binding_version: '0.2.0',
#         queue: {
#           name: 'on_contact_created',
#           durable: true,
#           auto_delete: true,
#           vhost: '/',
#           exclusive: true
#         },
#         exchange: {
#           name: 'crm_contact_created',
#           type: :fanout,
#           durable: true,
#           auto_delete: true,
#           vhost: '/'
#         }
#       }
#     }
#   end

#   let(:channel_item_key) { 'my_channel' }
#   let(:channel_item) do
#     { publish: publish_operation, bindings: channel_bindings }
#   end

#   let(:publish_operation) do
#     {
#       operation_id: 'on_crm_sugarcrm_contacts_contact_created',
#       summary: 'SugarCRM Contact Created',
#       message: {
#         "$ref":
#           '#/components/messages/crm_sugar_crm_contacts_contact_created_event',
#         payload: {
#           'hurray' => 'world!!'
#         }
#       },
#       bindings: {
#         binding_version: '0.2.0',
#         timestamp: Time.now.to_i,
#         expiration: 1,
#         priority: 1,
#         mandatory: true,
#         reply_to: 'crm.contact_created',
#         user_id: 'guest'
#       }
#     }
#   end

#   before { connection_proxy.start }
#   after { connection_proxy.close }

#   context 'a queue_proxy is passed rather than an exchange_proxy' do
#     let(:queue_proxy) do
#       EventSource::Protocols::Amqp::BunnyExchangeProxy.new(
#         channel_proxy,
#         channel_item
#       )
#     end

#     context "a valid #{described_class}" do
#       let(:exchange_proxy)
#       it 'should initialize with a BunnyExchangeProxy object' do
#         expect(described_class.new(exchange).subject).to eq exchange
#         EventSource::Protocols::Amqp::BunnyExchangeProxy.new(
#           channel_proxy,
#           channel_item
#         )
#       end

#       context 'Adapter pattern methods are present' do
#         let(:adapter_methods) { described_class::ADAPTER_METHODS }
#         it 'should have all the required methods' do
#           expect(described_class.new(queue_proxy)).to respond_to(
#             *adapter_methods
#           )
#         end
#       end
#     end
#   end
# end
