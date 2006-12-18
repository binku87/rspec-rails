module Spec
  module Expectations
    # TODO - DAC - This is mid-refactoring right now - I'd like to get ALL failure messages
    # for rspec and rspec_on_rails generated by this class so that we can
    # make any enhancements, improvements in one place. Right now it's pretty
    # scattered.
    class MessageBuilder
      def build_message(actual, expectation, expected)
        "#{actual.inspect} #{expectation} #{expected.inspect}"
      end
    end
  end
end