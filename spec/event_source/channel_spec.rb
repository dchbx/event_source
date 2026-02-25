# frozen_string_literal: true

require 'spec_helper'
require 'config_helper'

RSpec.describe EventSource::Channel do
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

  let(:publish_resource_path) do
    Pathname.pwd.join('spec', 'support', 'asyncapi', 'amqp_audit_log_publish.yml')
  end

  let(:subscribe_resource_path) do
    Pathname.pwd.join('spec', 'support', 'asyncapi', 'amqp_audit_log_subscribe.yml')
  end

  let(:publish_resource) do
    EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
      .new
      .call(path: publish_resource_path)
      .success
  end

  let(:subscribe_resource) do
    EventSource::AsyncApi::Operations::AsyncApiConf::LoadPath
      .new
      .call(path: subscribe_resource_path)
      .success
  end

  let(:connection_proxy) { connection.connection_proxy }
  let(:channel_proxy) { connection_proxy.add_channel(channel_item_key, publish_resource.channels.first) }
  let(:subscribe_channel_proxy) { connection_proxy.add_channel(subscribe_channel_item_key, subscribe_resource.channels.first) }

  subject do
    described_class.new(connection, channel_proxy, publish_resource.channels.first)
    described_class.new(connection, subscribe_channel_proxy, subscribe_resource.channels.first)
  end

  context 'When exchange to exchange bindings present' do

    let(:channel_item_key) { 'enroll.audit_log.events.created' }
    let(:subscribe_channel_item_key) { 'on_enroll.enroll.audit_log.events' }

    before { connection.start unless connection.active? }
    after { connection.disconnect if connection.active? }

    let(:exchange_names) { ['enroll.audit_log.events', 'enroll.enterprise.events', 'enroll.individual.enrollments'] }
    let(:audit_log_queue) { subscribe_channel_proxy.queues["on_enroll.enroll.audit_log.events"] }

    it 'should create exchanges' do
      exchange_names.each {|key| expect(channel_proxy.exchanges).not_to include(key) }
      subject
      exchange_names.each {|key| expect(channel_proxy.exchanges).to include(key) }
    end

    it 'should route messsages to audit log through exchange to exchange bindings' do
      subject

      audit_log_queue.purge
      sleep 1

      channel_proxy.exchanges['enroll.enterprise.events'].publish(
        'test message from enterprise events!!',
        routing_key: 'enroll.enterprise.date_advanced'
      )
      channel_proxy.exchanges['enroll.individual.enrollments'].publish(
        'test message from enrollment events!!',
        routing_key: 'enroll.individual.enrollments.coverage_selected'
      )

      sleep 1
      expect(audit_log_queue.message_count).to eq 2
      expect(audit_log_queue.pop.last).to eq 'test message from enterprise events!!'
      expect(audit_log_queue.pop.last).to eq 'test message from enrollment events!!'
    end

    context '.cancel_consumers' do
      before do
        subject.subscribe_operations.values.each do |sub_op|
          subscriber_klass = double('SubscriberKlass')
          sub_op.subscribe(subscriber_klass)
        end
      end

      it 'cancels consumers via channel' do
        channel = subject
        expect(channel.channel_proxy.any_consumers?).to be_truthy
        expect(channel.subscribe_operations.values.first.subject.consumers.count).to be > 0
        channel.cancel_consumers
        expect(channel.channel_proxy.any_consumers?).to be_falsey
        expect(channel.subscribe_operations.values.first.subject.consumers.count).to eq 0
      end
    end
  end
end
