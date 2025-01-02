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
  end
end
