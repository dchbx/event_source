# frozen_string_literal: true

require "spec_helper"

RSpec.describe EventSource::Operations::FetchSession do
  let(:fetch_session) { described_class.new }

  describe "when session helper not defined" do
    before do
      allow(fetch_session).to receive(:respond_to?).with(:session).and_return(
        respond_to_session
      )
      allow(fetch_session).to receive(:respond_to?).with(
        :current_user
      ).and_return(respond_to_current_user)
    end

    let(:respond_to_session) { true }
    let(:respond_to_current_user) { true }

    context "when current user not defined" do
      let(:respond_to_current_user) { false }

      it "should fail" do
        result = fetch_session.call

        expect(result.success?).to be_falsey
        expect(result.failure).to eq "current_user is not defined"
      end
    end

    context "when session not defined" do
      let(:respond_to_session) { false }

      it "should fail" do
        result = fetch_session.call

        expect(result.success?).to be_falsey
        expect(result.failure).to eq "session is not defined"
      end
    end
  end

  describe "when session helper defined" do
    context "when operation called" do
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

        def system_account
          OpenStruct.new(id: 2)
        end
      end

      let(:session_concern) { Class.new.extend(SessionConcern) }

      it "should return session and current user" do
        result = fetch_session.call

        expect(result.success?).to be_truthy
        expect(result.value!).to eq(
          [
            session_concern.session,
            session_concern.current_user,
            session_concern.system_account
          ]
        )
      end
    end
  end
end
