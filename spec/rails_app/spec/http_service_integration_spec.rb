# frozen_string_literal: true

require_relative './rails_helper'

RSpec.describe "with an http subscriber service" do
  include EventSource::Command

  it "runs when invoked" do
    $GLOBAL_TEST_FLAG = false

    WebMock.stub_request(
      :post,
      /http:\/\/localhost:3000\/determinations\/eval/
    ).to_return({body: "{}"})
    response = event("events.determinations.eval", attributes: {}).success.publish
    expect(response.status).to eq 200
    sleep(0.5)
    expect($GLOBAL_TEST_FLAG).to eq(true)
  end
end
