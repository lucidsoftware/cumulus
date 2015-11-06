require "common/BaseLoader"
require "conf/Configuration"

require "base64"

module Cumulus
  module EC2
    module InstanceLoader

      include Common::BaseLoader

      @@instances_dir = Configuration.instance.ec2.instances_directory
      @@user_data_dir = Configuration.instance.ec2.user_data_directory

      def self.instances
        Common::BaseLoader::resources(@@instances_dir, &InstanceConfig.method(:new))
      end

      def self.user_data(file)
        Common::BaseLoader::load_file(file, @@user_data_dir)
      end

      # Public: Returns a Hash of user data file name to base64 of its contents.
      def self.user_data_base64
        @user_data_base64 ||= Hash[Common::BaseLoader::resources(@@user_data_dir, false, &Proc.new do |name, contents|
          [name, Base64.encode64(contents)]
        end)]
      end

    end
  end
end