# frozen_string_literal: true

require_relative './rails_helper'

RSpec.describe EventSource::Railtie do
  it "runs when invoked" do
    manager = EventSource::ConnectionManager.instance
    connection = manager.connections_for(:amqp).first
    expect(connection).not_to be_nil
  end
end
