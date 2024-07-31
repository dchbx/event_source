require "spec_helper"
require "parallel_tests"
require "parallel_tests/rspec/runner"

RSpec.describe EventSource, "railtie specs" do
  it "runs the rails tests in the rails application context" do
    ParallelTests.with_pid_file do
      specs_run_result = ParallelTests::RSpec::Runner.run_tests(
        [
          "spec/rails_app/spec/railtie_spec.rb"
        ],
        1,
        1,
        {
          serialize_stdout: true,
          test_options: ["-O", ".rspec_rails_specs", "--format", "documentation"]
        }
      )
      if specs_run_result[:exit_status] != 0
        fail(specs_run_result[:stdout] + "\n\n")
      end
    end
  end
end