# frozen_string_literal: true

RSpec.describe EventSource::Operations::MimeEncode do
  subject { described_class.new }

  describe "#call" do

    let(:valid_payload) { { key: 'value' } }
    let(:invalid_payload) { -> {} }

    context "when MIME type is application/zlib" do
      let(:payload) { { message: "Hello, World!" } }
      let(:mime_type) { "application/zlib" }

      it "compresses the payload using Zlib" do
        result = subject.call(mime_type, payload)

        expect(result).to be_success
        expect(Zlib.inflate(result.value!)).to eq(payload.to_json)
      end
    end

    context "when MIME type is application/json" do
      let(:payload) { "Hello, World!" }
      let(:mime_type) { "application/json" }

      it "returns the payload as JSON" do
        result = subject.call(mime_type, payload)

        expect(result).to be_success
        expect(result.value!).to eq(payload.to_json)
      end
    end

    context "when the mime type is invalid" do
      let(:payload) { { message: "Hello, World!" } }
      let(:mime_type) { "text/plain" }

      it "returns a failure" do
        result = subject.call(mime_type, payload)

        expect(result).to be_failure
        expect(result.failure).to eq("Invalid MIME type 'text/plain'. Supported types are: application/zlib, application/json.")
      end
    end

    context 'when payload cannot be converted to JSON' do
      before do
        allow(invalid_payload).to receive(:to_json).and_raise(JSON::GeneratorError)
      end

      it 'returns a failure with JSON::GeneratorError' do
        result = subject.call('application/json', invalid_payload)

        expect(result).to be_failure
        expect(result.failure).to match(/Failed to encode payload to JSON:/)
      end
    end

    context 'when Zlib compression fails' do
      before do
        allow(Zlib).to receive(:deflate).and_raise(Zlib::Error, 'Compression failed')
      end

      it 'returns a failure with Zlib::Error' do
        result = subject.call('application/zlib', valid_payload)

        expect(result).to be_failure
        expect(result.failure).to eq('Failed to compress payload using Zlib: Compression failed')
      end
    end

    context 'when an unexpected error occurs' do
      before do
        allow(valid_payload).to receive(:to_json).and_raise(StandardError, 'something went wrong')
      end

      it 'returns a failure with StandardError' do
        result = subject.call('application/json', valid_payload)

        expect(result).to be_failure
        expect(result.failure).to eq('Unexpected error during encoding: something went wrong')
      end
    end
  end
end
