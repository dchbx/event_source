# frozen_string_literal: true

require 'spec_helper'
require 'config_helper'

RSpec.describe EventSource::Protocols::Amqp::BunnyQueueProxy do
  let(:protocol) { :amqp }
  let(:url) { 'amqp://localhost:5672/' }
  let(:protocol_version) { '0.9.1' }
  let(:description) { 'Development RabbitMQ Server' }

  let(:my_server) do
    {
      url: url,
      protocol: protocol,
      protocol_version: protocol_version,
      description: description
    }
  end

  let(:client) do
    EventSource::Protocols::Amqp::BunnyConnectionProxy.new(my_server)
  end
  let(:connection) { EventSource::Connection.new(client) }
  let(:channel_id) { 'crm_contact_created' }
  let(:publish_operation) do
    {
      operationId: 'on_crm_sugarcrm_contacts_contact_created',
      summary: 'SugarCRM Contact Created',
      message: {
        "$ref":
          '#/components/messages/crm_sugar_crm_contacts_contact_created_event',
        payload: {
          'hello' => 'world!!'
        }
      },
      bindings: {
        amqp: {
          bindingVersion: '0.2.0',
          timestamp: true,
          expiration: 1,
          priority: 1,
          mandatory: true,
          deliveryMode: 2,
          replyTo: 'crm.contact_created',
          userId: 'guest'
        }
      }
    }
  end

  let(:subscribe_operation) do
    {
      operationId: 'crm_sugarcrm_contacts_contact_created',
      summary: 'SugarCRM Contact Created',
      bindings: {
        amqp: {
          bindingVersion: '0.2.0',
          ack: true
        }
      }
    }
  end

  let(:channel_bindings) do
    {
      amqp: {
        is: :routing_key,
        binding_version: '0.2.0',
        queue: {
          name: 'on_polypress.crm_contact_created',
          durable: true,
          auto_delete: true,
          vhost: '/',
          exclusive: false
        },
        exchange: {
          name: 'crm_contact_created',
          type: :fanout,
          durable: true,
          auto_delete: true,
          vhost: '/'
        }
      }
    }
  end

  let(:async_api_publish_channel_item) do
    {
      id: 'publish channel id',
      publish: publish_operation,
      bindings: channel_bindings
    }
  end

  let(:async_api_subscribe_channel_item) do
    {
      id: 'subscribe channel id',
      subscribe: subscribe_operation,
      bindings: channel_bindings
    }
  end

  let(:subscribe_channel_struct) do
    EventSource::AsyncApi::ChannelItem.new(async_api_subscribe_channel_item)
  end

  let(:publish_channel_struct) do
    EventSource::AsyncApi::ChannelItem.new(async_api_publish_channel_item)
  end

  let(:channel) { connection.add_channel(channel_id, publish_channel_struct) }
  let(:channel_proxy) { channel.channel_proxy }

  let(:proc_to_execute) do
    proc do |delivery_info, metadata, payload|
      logger.info "delivery_info---#{delivery_info}"
      logger.info "metadata---#{metadata}"
      logger.info "payload---#{payload}"
      ack(delivery_info.delivery_tag)
      logger.info 'ack sent'
    end
  end

  subject { described_class.new(channel_proxy, subscribe_channel_struct) }

  before { connection.start unless connection.active? }
  after { connection.disconnect if connection.active? }

  context '.subscribe' do
    context 'when a valid subscribe block is defined' do
      it 'should execute the block' do
        subject
        expect(subject.consumer_count).to eq 0
        subject.subscribe(
          'SubscriberClass',
          subscribe_operation[:bindings],
          &proc_to_execute
        )
        expect(subject.consumer_count).to eq 1

        operation = channel.publish_operations.first[1]
        operation.call('Hello world!!!')

        sleep 2
      end

      it 'the closure should return a success exit code result'
    end

    context 'when an invalid subscribe block is defined' do
      context 'a block with syntax error' do
        it 'should return a failure exit code result'
        it 'should raise an exception'
      end

      context 'an unhandled exception occurs' do
        it 'should return a failure exit code result'
        it 'should send a critical error signal for devops'
      end
    end

    # context 'when block not passed' do
    #   it 'should subscribe to the queue' do
    #     expect(subject.consumer_count).to eq 0
    #     subject.subscribe(Class, subscribe_operation[:bindings])
    #     expect(subject.consumer_count).to eq 1
    #   end
    # end
  end

  context "executable lookup with subscriber suffix" do
    let(:connection_manager) { EventSource::ConnectionManager.instance }
    let!(:connection) { connection_manager.add_connection(my_server) }

    let(:event_log_subscriber) do
      Pathname.pwd.join(
        "spec",
        "rails_app",
        "app",
        "event_source",
        "subscribers",
        "event_log_subscriber.rb"
      )
    end

    let(:enterprise_subscriber) do
      Pathname.pwd.join(
        "spec",
        "rails_app",
        "app",
        "event_source",
        "subscribers",
        "enterprise_subscriber.rb"
      )
    end

    let(:publish_resource) do
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
        .new
        .call(
          path:
            Pathname.pwd.join(
              "spec",
              "support",
              "asyncapi",
              "amqp_audit_log_publish.yml"
            )
        )
        .success
    end

    let(:subscribe_resource) do
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
        .new
        .call(
          path:
            Pathname.pwd.join(
              "spec",
              "support",
              "asyncapi",
              "amqp_audit_log_subscribe.yml"
            )
        )
        .success
    end

    let(:subscribe_two_resource) do
      EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
        .new
        .call(
          path:
            Pathname.pwd.join(
              "spec",
              "support",
              "asyncapi",
              "amqp_enterprise_subscribe.yml"
            )
        )
        .success
    end

    let(:publish_channel) do
      connection.add_channel(
        "enroll.audit_log.events.created",
        publish_resource.channels.first
      )
    end
    let(:subscribe_channel) do
      connection.add_channel(
        "on_enroll.enroll.audit_log.events",
        subscribe_resource.channels.first
      )
    end
    let(:subscribe_two_channel) do
      connection.add_channel(
        "on_enroll.enroll.enterprise.events",
        subscribe_two_resource.channels.first
      )
    end

    let(:load_subscribers) do
      [event_log_subscriber, enterprise_subscriber].each do |file|
        require file.to_s
      end
    end

    before do
      allow(EventSource).to receive(:app_name).and_return("enroll")
      connection.start unless connection.active?
      publish_channel
      subscribe_channel
      subscribe_two_channel
      load_subscribers
      allow(subject).to receive(:exchange_name) { exchange_name }
    end

    let(:audit_log_proc) do
      EventSource::Subscriber.executable_container[
        "enroll.enroll.audit_log.events_subscribers_eventlogsubscriber"
      ]
    end

    let(:enterprise_advance_day_proc) do
      EventSource::Subscriber.executable_container[
        "enroll.enroll.enterprise.events.date_advanced_subscribers_enterprisesubscriber"
      ]
    end

    context "when routing key based executable is not found" do
      let(:delivery_info) do
        double(routing_key: "enroll.enterprise.events.date_advanced")
      end

      let(:exchange_name) { "enroll.audit_log.events" }

      it "should return default audit log proc" do
        executable =
          subject.find_executable(
            Subscribers::EventLogSubscriber,
            delivery_info
          )
        expect(executable).to match(audit_log_proc)
      end
    end

    context "when routing key based executable is found" do
      let(:delivery_info) do
        double(routing_key: "enroll.enterprise.events.date_advanced")
      end

      let(:exchange_name) { "enroll.enterprise.events" }

      it "should return executable for the routing key" do
        executable =
          subject.find_executable(
            Subscribers::EnterpriseSubscriber,
            delivery_info
          )
        expect(executable).to match(enterprise_advance_day_proc)
      end
    end
  end

  describe '#decode_payload' do
    let(:payload) { 'test_payload' }
    let(:mime_decode_operation) { instance_double(EventSource::Operations::MimeDecode) }
    let(:channel_proxy) { instance_double('ChannelProxy', subject: double) }
    let(:async_api_channel_item) { instance_double('AsyncApiChannelItem', bindings: channel_bindings) }

    let(:subscribe_operation) do
      EventSource::AsyncApi::SubscribeOperation.new(
        operationId: 'subscribe_message',
        bindings: { amqp: { key: 'value' } },
        message: {
          'bindings' => {
            'amqp' => {
              'contentEncoding' => 'application/zlib'
            }
          }
        }
      )
    end

    let(:instance) { described_class.new(channel_proxy, async_api_channel_item) }
    let(:channel_bindings) do
      {
        amqp: {
          is: :queue,
          queue: {
            name: 'on_event_source.test_queue',
            durable: true,
            exclusive: false,
            auto_delete: false,
            vhost: 'event_source'
          }
        }
      }
    end

    let(:bunny_queue) { instance_double('BunnyQueue') }

    before do
      allow_any_instance_of(described_class).to receive(:bunny_queue_for).and_return(bunny_queue)
      allow_any_instance_of(described_class).to receive(:bind_exchange).and_return(true)
      allow(async_api_channel_item).to receive(:subscribe).and_return(subscribe_operation)
      allow(EventSource::Operations::MimeDecode).to receive(:new).and_return(mime_decode_operation)
    end

    context 'when there is no message in the subscribe operation' do
      let(:subscribe_operation) { EventSource::AsyncApi::SubscribeOperation.new(operationId: 'subscribe_message' ) }

      it 'returns the original payload' do
        expect(instance.decode_payload(payload)).to eq(payload)
      end
    end

    context 'when there is no contentEncoding in the message bindings' do
      let(:subscribe_operation) { EventSource::AsyncApi::SubscribeOperation.new(operationId: 'subscribe_message', message: { }) }

      it 'returns the original payload' do
        expect(instance.decode_payload(payload)).to eq(payload)
      end
    end

    context 'when contentEncoding is provided' do
      context 'when decoding is successful' do
        let(:decoded_payload) { 'decoded_payload' }

        before do
          allow(mime_decode_operation).to receive(:call)
            .with('application/zlib', payload)
            .and_return(Dry::Monads::Success(decoded_payload))
        end

        it 'returns the decoded payload' do
          expect(instance.decode_payload(payload)).to eq(decoded_payload)
        end
      end

      context 'when decoding fails' do
        let(:failure_message) { 'Decoding error' }

        before do
          allow(mime_decode_operation).to receive(:call)
            .with('application/zlib', payload)
            .and_return(Dry::Monads::Failure(failure_message))
        end

        it 'logs the error and raises a PayloadDecodeError' do
          expect(instance.logger).to receive(:error).with("Failed to decompress message \n  due to: #{failure_message}")
          expect do
            instance.decode_payload(payload)
          end.to raise_error(EventSource::Error::PayloadDecodeError, failure_message)
        end
      end
    end
  end
end
