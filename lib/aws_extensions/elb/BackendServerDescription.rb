module AwsExtensions
  module ELB
    module BackendServerDescription

      # Implement comparison by using instance port
      def <=>(other)
        self.instance_port <=> other.instance_port
      end

    end
  end
end
