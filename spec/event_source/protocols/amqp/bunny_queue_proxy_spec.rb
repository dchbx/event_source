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
end
