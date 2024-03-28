# frozen_string_literal: true

# require 'spec_helper'

# 0. EventSource Gem supports domain model entities
# 1. Command
# 1.1 We will use Operations as ES Commands by doing: include EventSource::Events
# 1.2 An operation can have 1 or more Events
# 1.3 EventSource::Events builds events and fires event upon success of command
# 2. Event
# 2.1 Events are predefined and include attributes and validation using Dry Hash Schema & Dry Validation
# 3. Dispatcher
# 3.1 Use RuleSet and ListenerSet to register observers and distribute events
# 4. EventStream
# 4.1 Future: v0.3.0 will not include persistence

module EventSource
  class MyValidEvent < EventSource::Event
    publisher_path "parties.organization_publisher"
  end

  class MyEvent < EventSource::Event
    publisher_path "parties.organization_publisher"
    attribute_keys :hbx_id, :fein, :entity_kind
  end

  class MyEventTwo < EventSource::Event
    publisher_path "parties.organization_publisher"
  end

  class MyEventThree < EventSource::Event
    publisher_path "parties.organization_publisher"
    attribute_keys :hbx_id, :entity_kind, :fein, :legal_name
  end
end

RSpec.describe EventSource::Event do
  context "A new Event class" do
    # context "and a required publisher_path isn't provided" do
    #   let(:empty_event_class) do
    #     class MyEmptyEvent < EventSource::Event
    #       attribute_keys :hbx_id
    #     end
    #     MyEmptyEvent
    #   end
    #   let(:hbx_id) { '12345' }

    #   it 'should raise an EventSource::PublisherKeyMissing error' do
    #     expect do
    #       empty_event_class.new({ hbx_id: hbx_id })
    #     end.to raise_error EventSource::Error::PublisherKeyMissing
    #   end
    # end

    # context 'and the required publisher_path provided is invalid' do
    #   let(:invalid_publisher_path) do
    #     'undefined_module.undefined_event'
    #   end
    #   let(:invalid_event_class) do
    #     class InvalidEvent < EventSource::Event
    #       publisher_path 'undefined_module.undefined_event'
    #     end
    #     InvalidEvent
    #   end
    #   it 'should raise an EventSource::Errors::PublisherNotFound' do
    #     expect { invalid_event_class.new }.to raise_error EventSource::Error::ConstantNotDefined
    #   end
    # end

    context "and the required publisher_path provided is valid" do
      let(:valid_event_class) { EventSource::MyValidEvent }

      subject { valid_event_class.new }

      # it 'should initialize without error' do
      #   expect(subject.publisher_class).to be_a(Parties::OrganizationPublisher)
      # end

      it "should have an event_key" do
        expect(subject.name).to eq "event_source.my_valid_event"
      end
    end

    context "with a defined contract_class" do
      context "and the contract_class isn't defined" do
        it "should raise an EventSource::Errors::ContractNotDefined"
      end
    end
  end

  context "An initialized Event class with defined attribute_keys" do
    let(:event_class) { EventSource::MyEvent }

    it "keys should be initialized for each attribute" do
      expect(event_class.new.attribute_keys).to eq %i[hbx_id fein entity_kind]
    end

    subject { event_class.new(attributes: attributes) }

    # context 'and one or more attribute values are missing' do
    #   let(:attributes) { { hbx_id: '451231' } }

    #   it '#valid? should return false' do
    #     expect(subject.valid?).to be_falsey
    #   end
    # end

    context "and all attribute values are present" do
      let(:attributes) do
        { hbx_id: "553234", entity_kind: "c_corp", fein: "546232323" }
      end

      it "#valid? should return true" do
        expect(subject.valid?).to be_truthy
      end
    end

    # context 'and all attribute values are present along with additional attributes' do
    #   let(:attributes) do
    #     {
    #       hbx_id: '553234',
    #       entity_kind: 'c_corp',
    #       fein: '546232323',
    #       legal_name: 'Test Corp LLC'
    #     }
    #   end

    #   it '#valid? should return true' do
    #     expect(subject.valid?).to be_truthy
    #   end

    #   it 'should ignore extra attributes' do
    #     extra_keys = attributes.keys - subject.attribute_keys

    #     extra_keys.each { |key| expect(subject.payload.key?(key)).to be_falsey }
    #   end
    # end
  end

  context "An initialized Event class with no attribute_keys" do
    let(:event_class) { EventSource::MyEventTwo }

    subject { event_class.new }
    it "attribute_keys should be empty" do
      expect(subject.attribute_keys).to be_empty
    end

    context "with no attributes passed" do
      it "#event_errors should be empty" do
        expect(subject.event_errors).to be_empty
      end

      it "#valid? should return true" do
        expect(subject.valid?).to be_truthy
      end

      it "attributes should be an empty hash" do
        expect(subject.payload).to be_empty
      end
    end

    context "and with attributes passed" do
      let(:attributes) do
        {
          hbx_id: "553234",
          entity_kind: "c_corp",
          fein: "546232323",
          legal_name: "Test Corp LLC"
        }
      end

      subject { event_class.new(attributes: attributes) }

      it "#event_errors should be empty" do
        expect(subject.event_errors).to be_empty
      end
      it "#valid? should return true" do
        expect(subject.valid?).to be_truthy
      end
      it "should have all attributes" do
        expect(subject.payload).to eq attributes
      end
    end
  end

  context "An initialized Event class with attribute_keys" do
    let(:event_class) { EventSource::MyEventThree }

    context "with attributes passed" do
      let(:attributes) do
        {
          hbx_id: "553234",
          entity_kind: "c_corp",
          fein: "546232323",
          legal_name: "Test Corp LLC"
        }
      end

      subject { event_class.new(attributes: attributes) }

      it "attribute_keys should be present" do
        expect(subject.attribute_keys).to eq %i[
             hbx_id
             entity_kind
             fein
             legal_name
           ]
      end
      it "#event_errors should be empty" do
        expect(subject.event_errors).to be_empty
      end
      it "#valid? should return true" do
        expect(subject.valid?).to be_truthy
      end
      it "should have all attributes" do
        expect(subject.payload).to eq attributes
      end
    end

    # context 'with attribute setter' do
    #   let(:attributes) { { hbx_id: '553234', fein: '546232323' } }

    #   let(:metadata) { { event_key: 'parties.organization.created' } }

    #   subject { event_class.new(attributes: attributes, metadata: metadata) }

    #   context 'when a name value pair is passed' do
    #     let(:legal_name) { 'Test Corp LLC' }

    #     it 'should update attributes and errors' do
    #       expect(subject.event_errors.first).to include('legal_name')
    #       subject[:legal_name] = legal_name
    #       expect(subject.event_errors.first).not_to include('legal_name')
    #       expect(subject.payload[:legal_name]).to eq legal_name
    #     end
    #   end
    # end

    context "with attribute getter" do
      let(:attributes) { { hbx_id: "553234", fein: "546232323" } }

      subject { event_class.new(attributes: attributes) }

      context "when attribute name is passed" do
        it "should return the value" do
          expect(subject[:fein]).to eq attributes[:fein]
          expect(subject[:hbx_id]).to eq attributes[:hbx_id]
        end
      end
    end
  end

  describe "message composite event" do
    module EventSource
      class MyCustomEvent < EventSource::Event

        publisher_path "parties.organization_publisher"
      end
    end

    module SessionConcern
      def current_user
        OpenStruct.new(id: 1)
      end

      def session
        { "session_id" => "ad465b7f-1d9e-44b1-ba72-b97e166f3acb" }
      end
    end

    context "when event is message composite" do
      let(:options) do
        {
          payload: {
            subject_id: "gid://enroll/Person/53e693d7eb899ad9ca01e734",
            category: "hc4cc eligibility",
            event_time: DateTime.now
          },
          headers: {
            correlation_id: "edf0e41b-891a-42b1-a4b6-2dbd97d085e4",
            build_message: true
          }
        }
      end

      subject { EventSource::MyCustomEvent.new(options) }

      it "should build message" do
        expect(subject.message).to be_present
        expect(subject.message.headers[:account][:session]).to include(
          :session_id
        )
      end
    end
  end
end
