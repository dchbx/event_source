# frozen_string_literal: true

RSpec.describe EventSource::Operations::MimeEncode do
  subject { described_class.new }

  describe "#call" do
    context "when the payload and mime type are valid" do
      let(:payload) { { message: "Hello, World!" } }
      let(:mime_type) { "application/zlib" }

      it "successfully encodes the payload" do
        result = subject.call(mime_type, payload)

        expect(result).to be_success
        expect(Zlib.inflate(result.value!)).to eq(payload.to_json)
      end
    end

    context "when the payload is a string and mime type is valid" do
      let(:payload) { "Hello, World!" }
      let(:mime_type) { "application/json" }

      it "returns the payload as JSON" do
        result = subject.call(mime_type, payload)

        expect(result).to be_success
        expect(result.value!).to eq(payload)
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

    context "when the payload is invalid" do
      let(:payload) { 1000 }
      let(:mime_type) { "application/json" }

      it "returns a failure" do
        result = subject.call(mime_type, payload)

        expect(result).to be_failure
        expect(result.failure).to eq("Invalid payload type. Expected a Hash or String, but received Integer.")
      end
    end
  end
end
