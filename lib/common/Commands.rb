module Cumulus
  module Common
    # Public: Base class for the command line parser class.
    #
    # Classes that extend this class must provide the following methods:
    #
    #   self.manager - returns the manager for the AWS module that is being used.
    #
    # Additionally, the following methods can be set to change the behavior of the parser:
    #
    #   self.usage_message - returns the usage instructions.
    #   self.banner_message - returns the title, purpose, and behavior of the module. This is displayed in the help message.
    #   self.command_details - returns basic instructions on how to use each module command. This is displayed in the help message.
    #   self.valid_options - returns an array of the valid arguments where each argument is an array of valid commands.
    #   self.verify - ensures the commands are valid (proper order, right commands, etc) based on the array of arguments passed in.
    #   self.execute - runs the correct method on the manager based on the array of arguments passed in.
    #
    # The following super class is one example of what each method could look like. Change them in inherited classes as necessary.
    class Commands
      def self.usage_message
        options = valid_options
        options[0] = options[0].push("help")
        "Usage: cumulus #{manager_name}" + options.reduce(String.new) do |memo, param_list|
          memo + " [" + param_list.join("|") + "]"
        end + " <asset>"
      end

      def self.banner_message
        [
          "#{manager_name}: Manage #{manager_name.upcase}s.",
          "\tCompiles #{manager_name.upcase}s that are defined with configuration files and syncs the resulting #{manager_name.upcase} assets with AWS.",
        ].join("\n")
      end

      def self.command_details
        [
          "\tdiff\t- get a list of resources that have different definitions locally than in AWS (supplying the name of the group will diff only that group)",
          "\tlist\t- list the resources defined in configuration",
          "\tmigrate\t- create resource configuration files that match the definitions in AWS",
          "\tsync\t- sync the local resource definition with AWS (supplying the name of the resource will sync only that group). Also adds and removes users from groups",
        ].join("\n")
      end

      def self.help_message
        [
          "#{banner_message}",
          "",
          "#{usage_message}",
          "",
          "Commands",
          "#{command_details}"
        ].join("\n")
      end

      def self.manager
        require "common/manager/Manager"
        Cumulus::Common::Manager.new
      end

      # Retrieves the AWS module name by checking what ruby module the class is in.
      def self.manager_name
        manager.class.to_s.split("::")[1].downcase
      end

      def self.valid_options
        # The first array is the list of all possible first commands
        # The second array is the list of all possible second commands and so on.
        [["diff", "list", "migrate", "sync"]]
      end

      def self.verify(arguments)
        if arguments.size < valid_options.size or
          (arguments.size >= 1 and !(valid_options.size >= 1 and valid_options[0].push("help").include?(arguments[0]))) or
          (arguments.size >= 2 and !(valid_options.size >= 2 and valid_options[1].include?(arguments[1]))) or
          (arguments.size >= 3 and !(valid_options.size >= 3 and valid_options[2].include?(arguments[2]))) or
          puts usage_message
          exit
        end
      end

      def self.execute(arguments)
        if arguments[0] == "diff" and arguments.size == 2
          manager.diff_one(arguments[1])
        elsif arguments[0] == "sync" and arguments.size == 2
          manager.sync_one(arguments[1])
        else
          manager.method(arguments[0]).call
        end
      end

      # the main function called by the command line parser. DON'T OVERRIDE
      def self.parse(arguments)
        verify(arguments)

        if arguments[0] == "help"
          puts help_message
          exit
        end

        execute(arguments)
      end
    end
  end
end
