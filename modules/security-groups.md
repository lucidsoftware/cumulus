---
layout: module
title: Security Groups
image: assets/img/autoscaling.png
description: Create and manage security groups by name and with configuration.
---
Overview
--------
Security group rules can get complicated. If you accept traffic on a port from several security groups, you need to create individual rules for each allowed security group. Sometimes you need to allow traffic from specific IP addresses or subnets, but it can be hard to remember what they actually refer to. Cumulus simplifies security group configuration with its simple, compact format that refers to security groups and IP addresses subnets by name.

The following sections describe how to configure security groups using Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

### Security Group Definition
Each security group is defined in its own file. By default, these files are located in `conf/security/groups`, but that's [configurable](#configuration). Each security group gets its name from its filename (minus the `.json`, of course). Security group definitions are JSON objects with the following attributes:

* `description` - a description of the security group
* `vpc-id` - the id of the vpc the security group belongs to
* `tags` - an object who's keys and values will be used as tags for the security group
* `rules` - an object that contains the following attributes
  * `inbound` - an array of [rule definitions](#rule-definition) that will apply to inbound traffic
  * `outbound` - an array of [rule definitions](#rule-definition) that will apply to outbound traffic

Here's an example of a security group definition:

{% highlight json %}
{
  "description": "an example security group",
  "vpc-id": "",
  "tags": {
    "tag-key": "tag-value"
  },
  "rules": {
    "inbound": [...],
    "outbound": [...]
  }
}
{% endhighlight %}

### Rule Definition
Cumulus rule definitions are a compact method of specifying the security groups and subnets that have access to a particular security group. Rule definitions contain the following attributes:

* `protocol` - the protocol allowed by the rule
* `security-groups` - an array of security group names that are allowed through this rule
* `subnets` - an array of CIDR IPs that are allowed through this rule. Entries in this array can also be names of subnet groups defined in [subnets.json](#subnetsjson).
* `ports` - an array of ports allowed by the rule. Entries in this array can be integers for a single port or a string with the format `"{from port}-{to port}"` for a range of ports

Here's an example of a rule defintion:

{% highlight json %}
{
  "security-groups": [
    "a",
    "b"
  ],
  "protocol": "tcp",
  "ports": [
    "8000-8080",
    8081
  ],
  "subnets": [
    "10.0.0.0/24",
    "office-subnet"
  ]
}
{% endhighlight %}

This rule will make it so your security group allows the `a` and `b` security groups, the `10.0.0.0/24` subnet, and the subnets in `office-subnet` TCP access on ports 8000 to 8081.

### subnets.json
AWS allows you to give specific IP addresses and subnets access to a security group, but it's often hard to remember what these IP addresses correspond to. Cumulus lets you name and group subnets in `subnets.json` (the actual name and location of the file can be [configured](#configuration)).

`subnets.json` just contains a JSON object, the keys of which are the names of subnet groups, with values being arrays of CIDR notation IPs. Here's an example:

{% highlight json %}
{
  "recurly-ips": [
    "74.201.212.175"
    "64.74.141.175"
    "75.98.92.102"
    "74.201.212.0/24"
    "64.74.141.0/24"
    "75.98.92.96/28"
  ],
  "office-subnet": [
    "10.0.2.0/24"
  ]
}
{% endhighlight %}

With this defition, you can now reference the name `recurly-ips` in your rule definitions, and Cumulus will expand your rule defintion to include all the IPs listed for Recurly in your subnets.json. This feature can go a long way in making your security group defintions more readable and less error prone.

### Diffing and Syncing Security Groups
Cumulus's security group module has the following usage:

{% highlight bash %}
cumulus security-group [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Security groups can be diffed, listed, and synced (migration is covered in the [following section](#migration)). The three actions to the following:

* `diff` - Shows the differences between the local definition and the AWS security group configuration. If `<asset>` is specified, Cumulus will diff only the security group with that name.
* `list` - Lists the names of all the security groups defined in local configuration
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the security group with that name.

### Migration
Cumulus provides a `migrate` task to make your migration to Cumulus painless. AWS security group configuration is pulled down to produce Cumulus configuration.

During the migration, Cumulus will first merge your AWS rules that have matching ports. For example, if you allow security group `a` access on port 8080, and security group `b` access on port 8080, Cumulus will create a rule that combines the two.

Next, Cumulus will detect rules that contain the same combinations of security groups and subnets and merge their ports together. For example, if you have a rule that lets security groups `a` and `b` access on ports 8080 and 8888, and then another rule that gives security groups `a` and `b` access on port 4444, these two rules will be merged together.

Unfortunately, Cumulus has no way to group your subnets into `subnets.json` or to give them intelligent names, so you will have to go through the security group defintions and pull subnets into `subnets.json`. However, the initial two steps go a long way to make your migrated Cumulus configuration much easier to read than your original AWS configuration.

### Configuration
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the security group module:

* `$.security.groups.directory` - the directory where Cumulus expects to find security group definitions. Defaults to `conf/security/groups`
* `$.security.subnets-file` - the location of the `subnets.json` file. Defaults to `conf/security/subnets.json`
* `$.security.outbound-default-all-allowed` - whether all outbound traffic is allowed by default. More specifically, because AWS automatically creates a rule that allows all outbound traffic when creating a new security group, setting this value to true makes it so Cumulus ignores this rule if no outbound rules are specified for the security group. Setting this value will, obviously, make it so the outbound rule is deleted upon creation. Defaults to true.
