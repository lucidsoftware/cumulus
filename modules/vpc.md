---
layout: module
title: Virtual Private Cloud
image: assets/img/vpc.png
description: Create and manage VPCs
---
Overview
--------
Cumulus makes configuring Virtual Private Clouds simpler. Easily configure VPCs, route table definitions, subnets, and network acls. Read the following sections to learn about configuring your VPCs with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

Virtual Private Cloud
---------------------

Each VPC is defined in its own file where the file name is the name of the VPC. These files are located in a [configurable](#configuration) folder. VPCs are JSON objects with the following attributes:

* `cidr-block` - the network range for the VPC in CIDR notation e.g. `"10.0.0.0/16"`
* `tenancy` - the tenancy of instances launched in the VPC. A value of `"default"` means that instances can be launched with any tenancy and a value of `"dedicated"` means instances will launch as dedicated instances regardless of the tenancy assigned to the instance at launch
* `dhcp` - a JSON object containing DHCP options for the VPC. Updating DHCP options causes all existing and new instances launched in the VPC to use the new options
  * `domain-name-servers` - an array of up to 4 IP addresses for domain name servers or `"AmazonProvidedDNS"`
  * `domain-name` - if using `"AmazonProvidedDNS"` in `us-east-1` specifiy `"ec2.internal"`. If using `"AmazonProvidedDNS"` in another region, specify `{region}.compute.internal` (e.g. `"ap-northesat-1.compute.internal"`). Otherwise, specify a domain name
  * `ntp-servers` - an array of up to 4 IP addresses for NTP servers
  * `netbios-name-servers` - an array of up to 4 IP addresses for NetBIOS name servers
  * `netbios-node-type` - the NetBIOS node type. Valid values include `1`, `2`, `4`, or `8`
* `route-tables` - an array of named route table configurations that are associated with the VPC. See [Route Tables](#route-tables) for more information
* `endpoints` - an array of vpc endpoint configurations in JSON format with the following attributes:
  * `service-name` - the AWS service name in the form of `"com.amazonaws.{region}.{service}"`
  * `policy` - the name of the policy file to use for the endpoint. If omitted, AWS will replace the policy with a default policy. See [Endpoint Policies](#endpoint-policies) for more information on configuring policies
  * `route-tables` - an array of route table names or ids that are associated with the endpoint
* `address-associations` - a JSON object describing which Elastic IP addresses should be associated to network interfaces. The keys of the object are IP addresses while the values are network interface ids
* `network-acls` - an array of named Network ACL configurations to associate with the VPC. See [Network ACLs](#network-acls) for more information on configuration for individual ACLs
* `subnets` - an array of named subnet configurations to create in the VPC. See [Subnets](#subnets) for more information
* `tags` - an optional JSON object whose key/value pairs correspond to tag keys and values for the VPC e.g. `{ "TagName": "TagValue" }`

Here is an example of a VPC configuration:

{% highlight json %}
{
  "cidr-block": "10.0.0.0/16",
  "tenancy": "default",
  "dhcp": {
    "domain-name-servers": [
      "AmazonProvidedDNS"
    ],
    "domain-name": "ec2.internal"
  },
  "route-tables": [
    "route-table-1",
    "route-table-2"
  ],
  "endpoints": [
    {
      "service-name": "com.amazonaws.us-east-1.s3",
      "policy": null,
      "route-tables": [
        "route-table-1"
      ]
    }
  ],
  "address-associations": {
    "50.20.50.160": "eni-abc123"
  },
  "network-acls": [
    "network-acl-1"
  ],
  "subnets": [
    "subnet-1"
  ],
  "tags": {
    "Name": "vpc-1"
  }
}
{% endhighlight %}

### Route Tables

In Cumulus, route tables are configured in separate files from the VPC config to keep the VPC config simple for higher level changes. Route table configurations are stored in a [configurable](#configuration) directory for route tables. A route table has the following properties:

* `routes` - an array of route configurations for the route table. When creating a route, only one of `gateway-id`, `network-interface-id` or `vpc-peering-connection-id` should be specified. Each route is a JSON object with the following properties:
  * `dest-cidr` - the CIDR address block used for the destination match. Routing is based on the most specific match
  * `gateway-id` - the ID of an Internet gateway or virtual private gateway attached to your VPC
  * `network-interface-id` - the ID of a network interface
  * `vpc-peering-connection-id` - the ID of a VPC peering connection
* `propagate-vgws` - an optional array of virtual private gateway IDs that are allowed to propagate routes to this route table
* `tags - an optional JSON object whose key/value pairs correspond to tag keys and values for the VPC e.g. `{ "TagName": "TagValue" }`. In Cumulus, a route table can be referred to by the value of its `"Name"` tag in the VPC, VPC Endpoint, and Subnet configurations
* `exclude-cidr-blocks` - an optional array of CIDR address blocks to exlude when migrating, diffing, or syncing route tables with Cumulus. Any routes with a CIDR block in this list will not be created, deleted, or modified when syncing.

Here is an example of a route table with two routes that excludes routes with the address `"0.0.0.0/0"`

{% highlight json %}
{
  "routes": [
    {
      "dest-cidr": "10.3.0.0/16",
      "gateway-id": "vgw-abc123"
    },
    {
      "dest-cidr": "10.0.0.0/0",
      "network-interface-id": "eni-abc123"
    }
  ],
  "propagate-vgws": ["vgw-abc123"],
  "tags": {
    "Name": "route-table-1"
  },
  "exclude-cidr-blocks": [
    "0.0.0.0/0"
  ]
}
{% endhighlight %}


### Endpoint Policies

The EC2 API requires you to specify a policy when configuring a service endpoint. These policies are in the same format as [IAM policies]({{ site.baseurl }}/modules/iam.html#policy-definitions) and are stored in a [configurable](#configuration) policies directory

Here is an example of the current default policy used for service endpoints which allows all access to the service

{% highlight json %}
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
{% endhighlight %}

For more information see the [IAM module]({{ site.baseurl }}/modules/iam.html)


### Network ACLs

Network ACLs provide an optional layer of security for the instances in your VPC. In Cumulus, network acls are configured in separate files from the VPC config to keep the VPC config simple for higher level changes. Network ACL configurations are stored in a [configurable](#configuration) directory for network acls. A Network ACL has the following properties:

* `inbound` - an array of Network ACL entries defining inbound (ingress) rules for the ACL. Each entry is a JSON object with the following properties:
  * `rule` - the rule number for the entry. ACL entries are processed in ascending order by rule number. Valid values are in the range [1, 32766]. AWS recommends leaving large spaces between rule numbers so it is easier to add rules between other rules
  * `protocol` - a protocol keyword as defined by the [IANA](http://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml). Any protocols without keywords should instead be referred to by its decimal value
  * `action` - indicates where to allow or deny traffic matching the rule. Valid values are `"allow"` and `"deny"`
  * `cidr-block` - the network range in CIDR notation to allow or deny
  * `ports` - if protocol is `"UDP"` or `"TCP"`, the range of ports the rule applies to or a single port e.g. `"8000-8080"` or `80`
  * `icmp-type` - if protocol is `"ICMP"`, the ICMP type. `-1` means all types
  * `icmp-code` - if protocol is `"ICMP"`, the ICMP code. `-1` means all codes for the ICMP type
* `outbound` - an array of Network ACL entries defining outbound (egress) rules for the ACL. Each entry has the same configuration options as above
* `tags` - a JSON object whose key/value pairs correspond to tag keys and values for the VPC e.g. `{ "TagName": "TagValue" }`. In Cumulus, the `"Name"` tag must be defined on a Network ACL in order to reference it in a [subnet](#subnets) configuration

Here is an example of a Network ACL Configuration:

{% highlight json %}
{
  "inbound": [
    {
      "rule": 100,
      "protocol": "icmp",
      "action": "allow",
      "cidr-block": "10.1.0.0/16",
      "icmp-type": -1,
      "icmp-code": -1
    },
    {
      "rule": 200,
      "protocol": "tcp",
      "action": "allow",
      "cidr-block": "10.2.0.0/16",
      "ports": "8000-8080"
    },
    {
      "rule": 300,
      "protocol": "all",
      "action": "deny",
      "cidr-block": "0.0.0.0/0"
    }
  ],
  "outbound": [
    {
      "rule": 300,
      "protocol": "all",
      "action": "deny",
      "cidr-block": "0.0.0.0/0"
    }
  ],
  "tags": {
    "Name": "network-acl-1"
  }
}
{% endhighlight %}


### Subnets

In Cumulus, subnets are configured in separate files from the VPC config to keep the VPC config simple for higher level changes. Subnet configurations are stored in a [configurable](#configuration) subnets directory. A subnet has the following properties:

* `cidr-block` - the network range for the subnet in CIDR notation. Cannot be updated once a subnet is created
* `availability-zone` - the availability zone for the subnet. Cannot be updated once a subnet is created
* `map-public-ip` - specify `true` to indicate that instances launched within the subnet should be assigned public IP addresses
* `route-table` - the name or id of a route table to associate with the subnet
* `network-acl` - the name or id of a network acl to associate with the subnet
* `tags` - an optional JSON object whose key/value pairs correspond to tag keys and values for the VPC e.g. `{ "TagName": "TagValue" }`. In Cumulus, a subnet can be referred to by the value of its `"Name"` tag in the VPC configuration

Here is an example of a subnet configuration

{% highlight json %}
{
  "cidr-block": "10.0.0.0/16",
  "map-public-ip": true,
  "route-table": "route-table-1",
  "network-acl": "network-acl-1",
  "availability-zone": "us-east-1e",
  "tags": {
    "Name": "subnet-1"
  }
}
{% endhighlight %}


Diffing and Syncing VPCs
------------------------------

Cumulus's VPC module has the following usage:

{% highlight bash %}
cumulus vpc [diff|help|list|migrate|sync|rename] <asset>
{% endhighlight %}

VPCs can be diffed, listed, and synced (migration is covered in the [following section](#migration), and renaming is covered in a [later section](#renaming-assets)). The three actions do the following:

* `diff` - Shows the differences between the local definition and the AWS VPC configuration. If `<asset>` is specified, Cumulus will diff only the VPC with that name.
* `list` - Lists the names of all of the locally defined VPCs
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the VPC with that name.


Migration
---------

If your environment is anything like ours, you have dozens of VPCs, route tables, and subnets and would rather not write Cumulus configuration for them by hand. Luckily, Cumulus provides a `migrate` command that will pull down the needed configuration from AWS and save them to the local file system.

{% highlight bash %}
cumulus vpc migrate
{% endhighlight %}

This command will migrate all of the VPC configurations from AWS into identical local json versions in the `vpc/vpcs` directory, each named with the VPC name or id. Any route tables defined on the VPC will be migrated into `vpc/route-tables` and named with the route table name or id. Similarly, network acls and subnets will be migrated into the `vpc/network-acls` and `vpc/subnets` directories and named with network acl name or id and subnet name or id, respectively. Finally, endpoint policies that are attached to VPC endpoints will be migrated to `vpc/policies` and named with the `Version` of the policy.

After migration, you will notice that network acls will have a `Name` tag added to their tags (if there was not one previously) with the id of the Network ACL as the value. This is because we prefer to refer to network acls from Subnet config (instead of referring to subnets from ACL config) and need a way to identify a Network ACL besides its ID. We suggest using the [rename](#renaming-assets) command to update the name of migrated network acls and other assets to be more descriptive.


Renaming Assets
---------------

The VPC module provides a `rename` commmand to easily update the names of the various assets needed to manage a vpc. The rename command can be used as follows:

{% highlight bash %}
cumulus vpc rename [network-acl|policy|route-table|subnet|vpc] <old-asset-name> <new-asset-name>
{% endhighlight %}

Renaming an asset does 3 things:

1. The file name of the asset is updated to the new name
2. The value of the `"Name"` tag is updated with the new name (or created if it did not exist)
3. All references in other assets using the old name are updated to the new name, and affected files are saved again

Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the VPC module:

* `$.vpc.vpcs.directory` - the directory where Cumulus expects to find VPC definitions. Defaults to `conf/vpc/vpcs`.
* `$.vpc.subnets.directory` - the directory where Cumulus expects to find subnet definitions. Defaults to `conf/vpc/subnets`.
* `$.vpc.route-tables.directory` - the directory where Cumulus expects to find route table definitions. Defaults to `conf/vpc/route-tables`.
* `$.vpc.route-tables.routes.exclude-cidr-blocks` - an array of strings describing which CIDR blocks should be exluded from diffing, syncing and migrating when syncing a VPC's route tables.
* `$.vpc.policies.directory` - the directory where Cumulus expects to find policy definitions. Defaults to `conf/vpc/policies`.
* `$.vpc.network-acls.directory` - the directory where Cumulus expects to find network acl definitions. Defaults to `conf/vpc/network-acls`.