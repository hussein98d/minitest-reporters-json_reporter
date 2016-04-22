# json_reporter.rb - class Minitest::Reporters::JsonReporter

require 'json'
require 'time'
require 'minitest'
require 'minitest/reporters'

require_relative 'json_reporter/version'
require_relative 'json_reporter/test_detail'
require_relative 'json_reporter/pass_detail'
require_relative 'json_reporter/fault_detail'
require_relative 'json_reporter/skip_detail'
require_relative 'json_reporter/error_detail'
require_relative 'json_reporter/fail_detail'

# Minitest namespace - plugins must live here
module Minitest
  # Minitest::Reporters from minitest-reporters gem: See: https://github.com/kern/minitest-reporters
  module Reporters
    # Minitest Reporter that produces a JSON output for interface in IDEs, editor
    class JsonReporter < BaseReporter
      def initialize(my_options = {})
        super my_options
        @skipped = 0
        @failed = 0
        @errored = 0
        @passed = 0
        @storage = init_status
      end

      attr_reader :storage

      def metadata_h
        {
          generated_by: self.class.name,
          version: Minitest::Reporters::JsonReporter::VERSION,
          time: Time.now.utc.iso8601
        }
      end

      def init_status
        {
          status: green_status,
          metadata: metadata_h,
          statistics: statistics_h,
          fails: [],
          skips: []
        }
      end

      def record(test)
        super
        skipped(test) || errored(test) || failed(test) || passed(test)
      end

      def report
        super

        set_status # sets the success or failure and color in the status object
        # options only exists once test run starts
        @storage[:metadata][:options] = transform_store(options)
        @storage[:statistics] = statistics_h
        @storage[:timings] = timings_h
        # Only add this if not already added and verbose option is set
        @storage[:passes] ||= [] if options[:verbose]

        io.write(JSON.dump(@storage))
      end

      def yellow?
        @skipped > 0 && !red?
      end

      def green?
        !red? && !yellow?
      end

      def red?
        @failed + @errored > 0
      end

      private

      def set_status
        @storage[:status] = if red?
                              red_status
                            elsif yellow?
                              yellow_status
                            else
                              green_status
                            end
      end

      def color_h(code, color)
        { code: code, color: color }
      end

      def red_status
        color_h('Failed', 'red')
      end

      def yellow_status
        color_h('Passed, with skipped tests', 'yellow')
      end

      def green_status
        color_h('Success', 'green')
      end

      def timings_h
        {
          total_seconds: total_time,
          runs_per_second: count / total_time,
          assertions_per_second: assertions / total_time
        }
#                [total_time, count / total_time, assertions / total_time]
      end

      def statistics_h
        {
          total: @failed + @errored + @skipped + @passed,
          assertions: assertions,
          failed: @failed,
          errored: @errored,
          skipped: @skipped,
          passed: @passed
        }
      end

      def skipped(test)
        Minitest::Reporters::SkipDetail.new(test).query do |d|
          @skipped += 1
          @storage[:skips] << d.to_h
        end
      end

      def errored(test)
        Minitest::Reporters::ErrorDetail.new(test).query do |d|
          d.backtrace = filter_backtrace(d.backtrace)
          @storage[:fails] << d.to_h
          @errored += 1
        end
      end

      def failed(test)
        Minitest::Reporters::FailDetail.new(test).query do |d|
          @storage[:fails] << d.to_h
          @failed += 1
        end
      end

      # If it is increments @passed and optionally adds PassDetail object
      # to .passes array
      # if options[:verbose] == true
      def passed(test)
        Minitest::Reporters::PassDetail.new(test).query do |d|
          @passed += 1
          if options[:verbose]
            @storage[:passes] ||= []
            @storage[:passes] << d.to_h
          end
        end
      end

      # transform_store options: make pretty object for our JSON [metadata.options]
      # If :io is the IO class and == $stdout: "STDOUT"
      # Delete key: total_count
      def transform_store(opts)
        o = opts.clone
        o[:io] = o[:io].class.name
        o[:io] = 'STDOUT' if opts[:io] == $stdout
        o.delete(:total_count)
        o
      end
    end
  end
end
