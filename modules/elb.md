---
layout: module
title: Elastic Load Balancing
image: assets/img/ec2.png
description: Create and manage Elastic Load Balancers
---
Overview
--------
Cumulus makes configuring Elastic Load Balancers simpler. Easily configure load balancers, listeners, and policies. Read the following sections to learn about configuring your load balancers with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

Load Balancer Definition
-----------------------

Each load balancer is defined in its own file where the file name is the name of the load balancer. These files are located in a [configurable](#configuration) folder. Load balancers are JSON objects with the following attributes:

* `listeners` - the configuration for the listeners on the load balancer. Listeners can be defined using templates and/or inline (see [listeners](#listeners). At least one listener between `includes` and `inlines` must be present for a valid load balancer configuration. Has the following properties:
  * `includes` - an optional array of definitions for the template listeners to include. Each definition has the following properties:
    * `template` - the name of the template to include (without .json). The template should be located in the [configurable](#configuration) listeners directory.
    * `vars` - an object whose key-value pairs will override variables in the template
  * `inlines` - inline definitions for templates. See [listeners](#listeners) for detailed information
* `subnets` - an array of strings describing what subnets to attach the load balancer to. These can either be the subnet id or the value of the "Name" tag on the subnet (Cumulus will always try to use the "Name" tag to figure out which subnet is being used and default to treating the value as a subnet id)
* `security-groups` - an array of security group ids to apply to the load balancer
* `internal` - a true/false value indicating if the load balancing is internal facing (has a scheme of "internal"). Cannot be updated after a load balancer is created
* `tags` - an optional JSON object whose key/value pairs correspond to tag keys and values for the load balancer e.g. `{ "TagName": "TagValue" }`
* `manage-instances` - if false or omitted, instances will not be registered or deregistered with the load blancer when you sync. It can also be an array of instance ids that will be synced where any instances missing from here will be deregistered from the load balancer, and any that are added will be registered to the load balancer
* `health-check` - a JSON object that configures the health check parameters for the load balancer. It has the following properties:
  * `target` - the instance that will be checked on a health check. Must include protocol, port, and if protocol is HTTP or HTTPS, a path to ping. e.g. `"HTTP:80/checkhealth"`
  * `interval` - the between health checks on an instance (in seconds)
  * `timeout` - the amount of time (in seconds) to allow a health check to take before considering it a failed health check. Must be less than interval
  * `healthy` - the number of consecutive failures required before moving the instance to an Unhealthy state
  * `unhealthy` - the number of consecutive successes required before moving an instance to a Healthy state
* `backend-policies` - an optional array of JSON objects describing which backends have specific policies attached to them. Each definition consists of the following properties:
  * `port` - the instance port of the back end server to set policies for
  * `policies` - an array of policy names to set for the back end server. See [policies](#policies) for detailed information
* `cross-zone` - a true/false value indicating if this load balancer has cross-zone load balancing enabled
* `access-log` - if false or omitted, disables access logging. Otherwise it is a JSON object configuring access logging with the following properties:
  * `s3-bucket` - the name of the Amazon S3 bucket where access logs are stored
  * `emit-interval` - the interval (in minutes) for publishing the access logs. Currently only `5` and `60` are supported by AWS
  * `bucket-prefix` - the prefix to use when storing access logs to organize access logs e.g. `"load-balancer-name/prod"`
* `connection-draining` - if false or omitted then connection draining will be disabled. Otherwise, it is the maximum time (in seconds) to keep existing connections open before deregistering instances e.g. `"60"`
* `idle-timeout` - the time (in seconds) that the connection is allowed to be idle before it is closed by the load balancer

Here is an example of a load balancer with all options configured:

{% highlight json %}
{
  "listeners": {
    "includes": [
      {
         "template": "example-listener",
         "vars": {
            "ssl-cert": "value"
         }
      }
    ],
    "inlines": [
      {
        "load-balancer-protocol": "HTTP",
        "load-balancer-port": 80,
        "instance-protocol": "HTTP",
        "instance-port": 9001,
        "policies": ["ExampleCustomPolicy"]
      }
    ]
  },
  "subnets": [
    "named-subnet-1",
    "subnet-1111111a"
  ],
  "security-groups": [
    "sg-abc123de"
  ],
  "internal": true,
  "tags": {
    "tag-name": "tag-value"
  },
  "manage-instances": [
    "instance-id-1"
  ],
  "health-check": {
    "target": "HTTP:80/healthcheck.php",
    "interval": 10,
    "timeout": 8,
    "healthy": 2,
    "unhealthy": 5
  },
  "backend-policies": [
    {
      "port": 9001,
      "policies": ["ExampleCustomPolicy"]
    }
  ],
  "cross-zone": true,
  "access-log": {
    "s3-bucket": "my-bucket",
    "emit-interval": 5,
    "bucket-prefix": ""
  },
  "connection-draining": 100,
  "idle-timeout": 200
}
{% endhighlight %}

### Listeners

In Cumulus listeners can be configured on a load balancer using templates or inline. The configurations are identical, except that templates can have variables in the form of `{{variable-name}}` that will be overriden by the `"vars"` property in the load balancer config. Listener templates are stored in a [configurable](#configuration) listeners directory. A listener has the following properties:

* `load-balancer-protocol` - the protocol the load balancer will use for routing.  Valid values include `"HTTP"`, `"HTTPS"`, `"TCP"` or `"SSL"`
* `load-balancer-port` - the port the load balancer listens on. Only one listener per load balancer can have the same `load-balancer-port`
* `instance-protocol` - the protocol used for routing traffic to back end instances.  Valid values include `"HTTP"`, `"HTTPS"`, `"TCP"` or `"SSL"`
* `instance-port` - the port that the instance listens on.
* `policies` - an optional array of policy names to set on a listener. See [policies](#policies) for more information
* `ssl-certificate-id` - if the `load-balancer-protocol` or `instance-protocol` is `"HTTPS"` or `"SSL"` you may have to specify an SSL certificate to negotiate SSL.  See [AWS Documentation](http://docs.aws.amazon.com/ElasticLoadBalancing/latest/DeveloperGuide/elb-listener-config.html) for details

Here is an example of a listener template that routes HTTPS traffic and the ssl certificate id is a variable:

{% highlight json %}
{
  "load-balancer-protocol": "HTTPS",
  "load-balancer-port": 443,
  "instance-protocol": "HTTPS",
  "instance-port": 443,
  {% raw %}"ssl-certificate-id": "{{ssl-cert}}"{% endraw %},
  "policies": ["ExampleSecurityPolicy"]
}
{% endhighlight %}

### Policies

The AWS API for load balancer policies is very limiting. There is a set of default policies that can be set on listeners and backend servers when creating a load balancer from the web interface that are not allowed to be used in the API. Cumulus works around this by requiring policies on an already-created load balancer to either be defined locally, already created for the load balancer in AWS, or in the set of default policies provided by AWS. When creating new load balancers with Cumulus, all policies must be locally configured. When [migrating](#migration) policies will automatically be migrated with load balancers so that they can be managed by Cumulus. A local version of the list of default policies can also be obtained using [migration](#migration).

A local policy configuration will have a file name that is the same as the policy name and has the following properties:

* `type` - the policy type
* `attributes` - a JSON object whose key/value pairs are attribute names and attribute values.

Here is an example of a policy that enables ProxyProtocol:

{% highlight json %}
{
  "type": "ProxyProtocolPolicyType",
  "attributes": {
    "ProxyProtocol": "True"
  }
}
{% endhighlight %}

For detailed information on policies see [AWS Documentation](http://docs.aws.amazon.com/ElasticLoadBalancing/latest/DeveloperGuide/elb-security-policy-options.html)


Diffing and Syncing Load Balancers
------------------------------

Cumulus's ELB module has the following usage:

{% highlight bash %}
cumulus elb [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Load balancers can be diffed, listed, and synced (migration is covered in the [following section](#migration)). The three actions do the following:

* `diff` - Shows the differences between the local definition and the AWS ELB configuration. If `<asset>` is specified, Cumulus will diff only the load balancer with that name.
* `list` - Lists the names of all of the locally defined load balancers
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the load balancer with that name.


Migration
---------

If your environment is anything like ours, you have dozens of load balancers, and would rather not write Cumulus configuration for them by hand. Luckily, Cumulus provides a set of `migrate` tasks that will pull down your load balancers and produce configuration for them.

{% highlight bash %}
cumulus elb migrate default-policies
{% endhighlight %}

This command will migrate all of the default policies from AWS into identical local json versions in the `elb-default-policies` directory, each named `Cumulus-<PolicyName>.json`. This is necessary if you want to change the security policy of migrated load balancers to one of the other default policies or create a load balancer using the default policies because the ELB API does not allow you to update using the default-named policies.

{% highlight bash %}
cumulus elb migrate elbs
{% endhighlight %}

This command will migrate all of your load balancers from AWS to local configuration in the `elb-load-balancers` directory. As load balancers are migrated, any non-default policies defined on a load balancer will be migrated to the `elb-policies` directory.

After migration you should copy the policies in `elb-default-policies` and `elb-policies` to the [configurable](#configuration) policies directory so that diffing and syncing will be able to read the policy definitions.

Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the ELB module:

* `$.elb.load-balancers.directory` - the directory where Cumulus expects to find load balancer definitions. Defaults to `conf/elb/load-balancers`.
* `$.elb.listeners.directory` - the directory where Cumulus expects to find listener templates. Defaults to `conf/elb/listeners`.
* `$.elb.policies.directory` - the directory where Cumulus expects to find policy definitions. Defaults to `conf/elb/policies`.