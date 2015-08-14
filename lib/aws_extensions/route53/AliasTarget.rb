module AwsExtensions
  module Route53
    module AliasTarget
      # Public: Method that will reformat the dns_name of an ELB from Route53 alias
      # to be the same as the dns_name on a regular ELB.
      #
      # Returns the string reformatted dns_name
      def elb_dns_name
        dns_name.sub(/^dualstack\./, '').chomp(".")
      end

      # Public: Method that will reformat the dns_name to remove the trailing "." from
      # the dns_name if it is present.
      #
      # Returns the string reformatted dns_name
      def chomped_dns
        dns_name.chomp(".")
      end
    end
  end
end
