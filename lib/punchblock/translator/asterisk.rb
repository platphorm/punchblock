require 'celluloid'
require 'punchblock/core_ext/celluloid'
require 'ruby_ami'

module Punchblock
  module Translator
    class Asterisk
      include Celluloid

      extend ActiveSupport::Autoload

      autoload :AMIAction
      autoload :Call
      autoload :Component

      attr_reader :ami_client, :connection

      def initialize(ami_client, connection)
        @ami_client, @connection = ami_client, connection
        @calls, @components = {}, {}
        @fully_booted_count = 0
      end

      def register_call(call)
        @calls[call.id] ||= call
      end

      def call_with_id(call_id)
        @calls[call_id]
      end

      def register_component(component)
        @components[component.id] ||= component
      end

      def component_with_id(component_id)
        @components[component_id]
      end

      def handle_ami_event(event)
        return unless event.is_a? RubyAMI::Event
        if event.name.downcase == "fullybooted"
          @fully_booted_count += 1
          if @fully_booted_count >= 2
            connection.handle_event Connection::Connected.new
            @fully_booted_count = 0
          end
        else
          connection.handle_event Event::Asterisk::AMI::Event.new(:name => event.name, :attributes => event.headers)
        end
      end

      def execute_command(command, options = {})
        command.request!
        if command.call_id || options[:call_id]
          command.call_id ||= options[:call_id]
          if command.component_id || options[:component_id]
            command.component_id ||= options[:component_id]
            execute_component_command command
          else
            execute_call_command command
          end
        else
          execute_global_command command
        end
      end

      def execute_call_command(command)
        call_with_id(command.call_id).execute_command command
      end

      def execute_component_command(command)
        call_with_id(command.call_id).execute_component_command command
      end

      def execute_global_command(command)
        component = AMIAction.new command, ami_client
        # register_component component
        component.execute!
      end
    end
  end
end