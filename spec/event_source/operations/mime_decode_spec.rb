# frozen_string_literal: true

RSpec.describe EventSource::Operations::MimeDecode do
  subject { described_class.new }

  describe "#call" do
    context "when the payload and mime type are valid" do
      let(:payload) { { message: "Hello, World!" } }
      let(:compressed_payload) { Zlib.deflate(payload.to_json) }
      let(:mime_type) { "application/zlib" }

      it "successfully decodes the payload" do
        result = subject.call(mime_type, compressed_payload)

        expect(result).to be_success
        expect(result.value!).to eq(payload.to_json)
      end
    end

    context "when the payload is not binary for application/zlib" do
      let(:invalid_payload) { "Not binary data" }
      let(:mime_type) { "application/zlib" }

      it "returns a failure" do
        result = subject.call(mime_type, invalid_payload)

        expect(result).to be_failure
        expect(result.failure).to eq("Payload must be binary-encoded for MIME type 'application/zlib'.")
      end
    end

    context "when the mime type is invalid" do
      let(:payload) { { message: "Hello, World!" }.to_json }
      let(:mime_type) { "text/plain" }

      it "returns a failure" do
        result = subject.call(mime_type, payload)

        expect(result).to be_failure
        expect(result.failure).to eq("Invalid MIME type 'text/plain'. Supported types are: application/zlib, application/json.")
      end
    end

    context "when decoding fails" do
      let(:invalid_compressed_payload) { "Invalid compressed data" }
      let(:mime_type) { "application/zlib" }

      it "returns a failure with an error message" do
        result = subject.call(mime_type, invalid_compressed_payload)

        expect(result).to be_failure
        expect(result.failure).to eq("Payload must be binary-encoded for MIME type 'application/zlib'.")
      end
    end

    context "when the mime_type is 'application/zlib'" do
      context "and the payload is a JSON string but not binary" do
        let(:json_string) { "Invalid compressed data".to_json }
        let(:mime_type) { "application/zlib" }
    
        it "passes validation" do
          result = subject.call(mime_type, json_string)
    
          expect(result).to be_success
          expect(result.value!).to eq(json_string)
        end
      end
    
      context "and the payload is neither binary nor valid JSON" do
        let(:non_json_payload) { "Invalid compressed data" }
        let(:mime_type) { "application/zlib" }
    
        it "returns a failure with a validation error message" do
          result = subject.call(mime_type, non_json_payload)
    
          expect(result).to be_failure
          expect(result.failure).to eq("Payload must be binary-encoded for MIME type 'application/zlib'.")
        end
      end
    
      context "and the payload is not binary and raises an error when parsed as JSON" do
        let(:corrupted_json_payload) { "Invalid compressed data" }
        let(:mime_type) { "application/zlib" }
    
        before do
          allow(JSON).to receive(:parse).with(corrupted_json_payload).and_raise(JSON::ParserError)
        end
    
        it "returns a failure with a validation error message" do
          result = subject.call(mime_type, corrupted_json_payload)
    
          expect(result).to be_failure
          expect(result.failure).to eq("Payload must be binary-encoded for MIME type 'application/zlib'.")
        end
      end

      context 'when Zlib.inflate raises an exception' do
        let(:payload) { { message: "Hello, World!" } }
        let(:invalid_compressed_payload) { Zlib.deflate(payload.to_json) }

        it 'returns the original payload wrapped in Success' do
          allow(Zlib).to receive(:inflate).and_raise(Zlib::DataError, "invalid compressed data")

          result = subject.call('application/zlib', invalid_compressed_payload)

          expect(result).to be_a(Dry::Monads::Success)
          expect(result.value!).to eq(invalid_compressed_payload)
        end
      end
    end
  end
end
