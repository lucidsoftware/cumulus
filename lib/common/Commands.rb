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
    #   self.parse - ensures the commands are valid (proper order, right commands, etc), then displays the help message if necessary, then calls execute().
    #   self.execute - runs the correct method on the manager.
    #
    # The following super class is one example of what each method could look like. Change them in inherited classes as necessary.
    class Commands
      def self.usage_message
        options = valid_options
        options[0] = options[0].push("help")
        "Usage: cumulus #{manager_name}" + options.reduce(String.new) do |memo, param_list|
          memo + " [" + param_list.join("|") + "]"
        end
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
        [["diff", "list", "migrate", "sync"], ["asset"]]
      end

      def self.parse
        if ARGV.size == 1 or
          (ARGV.size >= 2 and !(valid_options.size >= 1 and valid_options[0].push("help").include?(ARGV[1]))) or
          (ARGV.size >= 3 and !(valid_options.size >= 2 and valid_options[1].include?(ARGV[2])) and valid_options[1] != ["asset"]) or
          (ARGV.size >= 4 and !(valid_options.size >= 3 and valid_options[2].include?(ARGV[3])) and valid_options[2] != ["asset"]) or
          ARGV.size - 1 > valid_options.size
          puts usage_message
          exit
        end

        if ARGV[1] == "help"
          puts help_message
          exit
        end

        execute
      end

      def self.execute
        if ARGV[1] == "diff" and ARGV.size == 3
          manager.diff_one(ARGV[2])
        elsif ARGV[1] == "sync" and ARGV.size == 3
          manager.sync_one(ARGV[2])
        else
          manager.method(ARGV[1]).call
        end
      end
    end
  end
end
