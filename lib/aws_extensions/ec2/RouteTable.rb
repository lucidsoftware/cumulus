module AwsExtensions
  module EC2
    module RouteTable

      # Public: Returns the value of the "Name" tag for the route table
      def name
        self.tags.select { |tag| tag.key == "Name" }.first.value
      rescue
      	nil
      end

      # Public: Returns an array of subnet ids associated with the route table
      def subnet_ids
        self.associations.map { |assoc| assoc.subnet_id }
      end

      # Public: Selects the routes in the route table that we care about by filtering out
      # the default route with the local gateway and any routes that are for s3 service endpoints
      # (ones that have a destination_prefix_list_id)
      def diffable_routes
        self.routes.select { |route| route.gateway_id != "local" and route.origin != "CreateRouteTable" and route.destination_prefix_list_id.nil? }
      end

    end
  end
end
