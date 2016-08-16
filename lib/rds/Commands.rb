module Cumulus
  module RDS
    require "common/Commands"
    class Commands < Cumulus::Common::Commands

      def self.banner_message
        format_message [
          "rds: Manage Relational Database Service.",
          "\tCompiles rds resources that are defined in configuration files and syncs the resulting RDS assets with AWS.",
        ]
      end

      def self.manager
        require "rds/manager/Manager"
        Cumulus::RDS::Manager.new
      end

    end
  end
end
