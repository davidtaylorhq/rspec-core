require "spec_helper"
require "support/runner_support"

module RSpec::Core
  RSpec.describe "Configuration :suite hooks" do
    [:before, :after].each do |type|
      describe "a(n) #{type} hook" do
        it 'is skipped when in dry run mode' do
          RSpec.configuration.dry_run = true

          expect { |b|
            RSpec.configuration.__send__(type, :suite, &b)
            RSpec.configuration.with_suite_hooks { }
          }.not_to yield_control
        end

        it 'allows errors in the hook to propagate to the user' do
          RSpec.configuration.__send__(type, :suite) { 1 / 0 }

          expect {
            RSpec.configuration.with_suite_hooks { }
          }.to raise_error(ZeroDivisionError)
        end

        context "defined on an example group" do
          it "is ignored with a clear warning" do
            sequence = []

            expect {
              RSpec.describe "Group" do
                __send__(type, :suite) { sequence << :suite_hook }
                example { sequence << :example }
              end.run
            }.to change { sequence }.to([:example]).
              and output(a_string_including("#{type}(:suite)")).to_stderr
          end
        end
      end
    end

    it 'always runs `after(:suite)` hooks even in the face of errors' do
      expect { |b|
        RSpec.configuration.after(:suite, &b)
        RSpec.configuration.with_suite_hooks { raise "boom" }
      }.to raise_error("boom").and yield_control
    end

    describe "the runner" do
      include_context "Runner support"

      it "runs :suite hooks before and after example groups in the correct order" do
        sequence = []

        config.before(:suite)         { sequence << :before_suite_1 }
        config.before(:suite)         { sequence << :before_suite_2 }
        config.prepend_before(:suite) { sequence << :before_suite_3 }
        config.after(:suite)          { sequence << :after_suite_1  }
        config.after(:suite)          { sequence << :after_suite_2  }
        config.append_after(:suite)   { sequence << :after_suite_3  }


        example_group = class_double(ExampleGroup, :descendants => [])

        allow(example_group).to receive(:run) { sequence << :example_groups }
        allow(world).to receive_messages(:ordered_example_groups => [example_group])
        allow(config).to receive :load_spec_files

        runner = build_runner
        runner.run err, out

        expect(sequence).to eq([
          :before_suite_3,
          :before_suite_1,
          :before_suite_2,
          :example_groups,
          :after_suite_2,
          :after_suite_1,
          :after_suite_3
        ])
      end
    end
  end
end