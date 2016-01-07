require "ec2/EC2"

module AwsExtensions
  module EC2
    module SecurityGroup

      # Public: Returns the name of the security group prefixed by the vpc name or id
      def vpc_group_name
        vpc = Cumulus::EC2::id_vpcs[self.vpc_id]
        vpc_name = if vpc then "#{vpc.name}/" else "" end
        "#{vpc_name}#{self.group_name}"
      end

    end
  end
end
