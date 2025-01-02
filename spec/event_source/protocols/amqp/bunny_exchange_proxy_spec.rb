# frozen_string_literal: true

require 'spec_helper'
require 'config_helper'

RSpec.describe EventSource::Protocols::Amqp::BunnyExchangeProxy do
  let(:channel_proxy) { instance_double('BunnyChannelProxy', subject: double) }
  let(:exchange_bindings) do
    {
      type: :direct,
      name: 'test_exchange',
      durable: true,
      auto_delete: false,
      vhost: 'test_vhost'
    }
  end
  let(:bunny_exchange) { instance_double('Bunny::Exchange', name: 'test_exchange') }
  let(:payload) { { message: 'test message' } }
  let(:publish_bindings) { { routing_key: 'test.key', persistent: true } }
  let(:headers) { { correlation_id: '12345', custom_header: 'test_value' } }

  subject { described_class.new(channel_proxy, exchange_bindings) }

  before do
    allow_any_instance_of(described_class).to receive(:bunny_exchange_for).and_return(bunny_exchange)
    allow(bunny_exchange).to receive(:publish)
  end

  describe '#publish' do
    it 'publishes the payload with the correct bindings and headers' do
      subject.publish(payload: payload, publish_bindings: publish_bindings, headers: headers)

      expect(bunny_exchange).to have_received(:publish).with(payload.to_json, {
        correlation_id: '12345',
        headers: { custom_header: 'test_value' }
      })
    end

    it 'logs the publishing process' do
      expect(subject.logger).to receive(:debug).with(/publishing message with bindings:/)
      expect(subject.logger).to receive(:debug).with(/published message:/)
      expect(subject.logger).to receive(:debug).with(/published message to exchange:/)

      subject.publish(payload: payload, publish_bindings: publish_bindings, headers: headers)
    end

    context 'when the payload is binary' do
      let(:binary_payload) { Zlib.deflate("binary data") }

      it 'does not convert the payload to JSON' do
        subject.publish(payload: binary_payload, publish_bindings: publish_bindings, headers: headers)

        expect(bunny_exchange).to have_received(:publish).with(binary_payload, {
          correlation_id: '12345',
          headers: { custom_header: 'test_value' }
        })
      end
    end
  end
end
