require "ec2/EC2"

module AwsExtensions
  module EC2
    module Subnet

      # Public: Returns the value of the "Name" tag for the subnet or nil if there is not one
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
        nil
      end

      # Public: Returns the name of the security group prefixed by the vpc name or id
      def vpc_subnet_name
        vpc = Cumulus::EC2::id_vpcs[self.vpc_id]
        vpc_name = vpc.name || vpc.vpd_id
        "#{vpc_name}/#{self.name}"
      end

      # Implement comparison by using subnet id
      def <=>(other)
        self.subnet_id <=> other.subnet_id
      end

    end
  end
end
