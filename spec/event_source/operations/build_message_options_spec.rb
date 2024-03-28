# frozen_string_literal: true

require "spec_helper"

RSpec.describe EventSource::Operations::BuildMessageOptions do
  module SessionConcern
    def current_user
      OpenStruct.new(id: 1)
    end

    def session
      {
        "session_id" => "ad465b7f-1d9e-44b1-ba72-b97e166f3acb",
        "portal" => "enroll/families/home",
        "login_session_id" => "ad465b7f-1d9e-44b1-ba72-b97e166f3acb"
      }
    end
  end

  context "input params passed" do
    let(:input_params) do
      {
        payload: {
          record: double
        },
        headers: {
          event_name: "events.hc4cc.eligibilities.created",
          event_category: "hc4cc_eligibility",
          event_time: DateTime.now,
          event_outcome: "eligibility created",
          subject_id: "gid://enroll/Person/53e693d7eb899ad9ca01e734",
          resource_id: "gid://enroll/Eligibility/53e693d7eb899ad9ca01e734",
          market_kind: "individual"
        },
        event_name: "enroll.events.person.hc4cc_eligibility.created"
      }
    end

    context "when params passed" do
      it "should return success" do
        result = subject.call(input_params)

        expect(result.success?).to be_truthy
      end

      it "should build headers" do
        result = subject.call(input_params)
        message_options = result.value!

        expect(message_options[:headers]).to be_a(Hash)
        expect(message_options[:headers].keys).to match_array(
          %i[
            correlation_id
            subject_id
            resource_id
            event_category
            message_id
            event_name
            event_time
            event_outcome
            market_kind
            account
          ]
        )
      end

      it "should build payload" do
        result = subject.call(input_params)
        message_options = result.value!

        expect(message_options[:payload]).to be_a(Hash)
        expect(message_options[:payload].keys).to match_array(%i[record])
      end

      it "should build session options" do
        result = subject.call(input_params)
        message_options = result.value!

        expect(message_options[:headers][:account][:session]).to be_a(Hash)
        expect(message_options[:headers][:account][:session].keys).to match_array(
          %i[session_id portal login_session_id]
        )
      end
    end
  end
end
