module Spec
  module Api
    class Mock

      DEFAULT_OPTIONS = {
        :null_object => false
      }
      # Creates a new mock with a +name+ (that will be used in error messages only)
      # Options:
      # * <tt>:null_object</tt> - if true, the mock object acts as a forgiving null object allowing any message to be sent to it.
      def initialize(name, options={})
        @name = name
        @options = DEFAULT_OPTIONS.dup.merge(options)
        @expectations = []
      end
      
      def should
        self
      end

      def receive(sym, &block)
        expected_from = caller(1)[0]
        expectation = MessageExpectation.new(@name, expected_from, sym, block_given? ? block : nil)
        @expectations << expectation
        expectation
      end

      def __verify
        @expectations.each do |expectation|
          expectation.verify_messages_received
        end
      end

      def method_missing(sym, *args, &block)
        # TODO: use find_expectation(sym, args) which will lookup based on sym, args and strict mode.
        if expectation = find_matching_expectation(sym, *args)
          expectation.verify_message(args, block)
        else
          begin
            # act as null object if method is missing and we ignore them. return value too!
            @options[:null_object] ? self : super(sym, *args, &block)
          rescue NoMethodError
            
            arg_message = args.collect{|arg| "<#{arg}:#{arg.class.name}>"}.join(", ")
            
            raise Spec::Api::MockExpectationError, "Mock '#{@name}' received unexpected message '#{sym.to_s}' with [#{arg_message}]"
          end
        end
      end

    private

      def find_matching_expectation(sym, *args)
        expectation = @expectations.find {|expectation| expectation.matches(sym, args)}
      end

    end

    # Represents the expection of the reception of a message
    class MessageExpectation

      def initialize(mock_name, expected_from, sym, block)
        @mock_name = mock_name
        @expected_from = expected_from
        @sym = sym
        @method_block = block
        @block = proc {}
        @received_count = 0
        @expected_received_count = 1
        @expected_params = nil
        @consecutive = false
        @any_seen = false
        @at_seen = false
      end
  
      def matches(sym, args)
        @sym == sym and (@expected_params.nil? or @expected_params == args)
      end

      # This method is called at the end of a spec, after teardown.
      def verify_messages_received
        # TODO: this doesn't provide good enough error messages to fix the error.
        # Error msg should tell exactly what went wrong. (AH).
    
        return if @expected_received_count == -2
        return if (@expected_received_count == -1) && (@received_count > 0)
        return if @expected_received_count == @received_count
    
        expected_signature = nil
        if @expected_params.nil?
          expected_signature = @sym
        else
          params = @expected_params.collect{|param| "<#{param}:#{param.class.name}>"}.join(", ")
          expected_signature = "#{@sym}(#{params})"
        end
    
        count_message = "{@expected_received_count} times"
        count_message = "at least once" if (@expected_received_count == -1)
        count_message = "never" if (@expected_received_count == 0)
        count_message = "once" if (@expected_received_count == 1)
        count_message = "twice" if (@expected_received_count == 2)

        message = "Mock '#{@mock_name}' expected #{expected_signature} #{count_message}, but received it #{@received_count} times"
        begin
          raise Spec::Api::MockExpectationError, message
        rescue => error
          error.backtrace.insert(0, @expected_from)
          raise error
        end
      end

      # This method is called when a method is invoked on a mock
      def verify_message(args, block)
        unless @method_block.nil?
          begin
            result = @method_block.call(*args)
          rescue Spec::Api::ExpectationNotMetError => detail
            raise Spec::Api::MockExpectationError, "Call expectation violated with: " + $!
          end
          @received_count += 1
          return result
        end
    
        unless @expected_params.nil? or @expected_params == args
          raise Spec::Api::MockExpectationError,
            "#{@sym}: Parameter mismatch: Expected <#{@expected_params}>, got <#{args}>" 
        end
        args << block unless block.nil?
        @received_count += 1
        value = @block.call(*args)
    
        return value unless @consecutive
    
        value[[@received_count, value.size].min - 1]
      end

      def with(*args)
        if args == [:anything] then @expected_params = nil
        elsif args == [:nothing] then @expected_params = []
        else @expected_params = args
        end

        self
      end
  
      def at
        @at_seen = true
        self
      end
      
      def exactly(n)
        @expected_received_count = n
        self
      end
      
      def least(arg)
        @expected_received_count = -1 if ((arg == :once) and (@at_seen))
        @at_seen = false
        self
      end

      def any
        @any_seen = true
        self
      end
      
      def number
        @number_seen = @any_seen
        @any_seen = false
        self
      end
      
      def of
        @of_seen = @number_seen
        @number_seen = false
        self
      end
      
      def times
        @expected_received_count = -2 if @of_seen
        @of_seen = false
        self
      end
  
      def never
        @expected_received_count = 0
        self
      end
  
      def once
        @expected_received_count = 1
        self
      end
  
      def twice
        @expected_received_count = 2
        self
      end
  
      def and
        self
      end

      def return(value=nil,&block)
        @consecutive = value.instance_of? Array
        @block = block_given? ? block : proc { value }
      end
  
    end
  end
end