---
layout: module
title: Route53
image: assets/img/route53.svg
description: Create and manage Route53 hosted zones and records.
---
Overview
--------
Cumulus makes using Route53 easier and cleaner! Create files containing common records to be included in multiple hosted zones! Reference AWS resources by name in alias records! Read the following sections to learn about configuring your Route53 environment with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

Zone Definition
---------------

Each hosted zone is defined in its own file, and the folder zones are located in is [configurable](#configuration). In other Cumulus modules, you've probably seen that managed assets get their names from the names of the files in which they are defined. However, because you can have two hosted zones that share a name and differ by their privacy settings, file names for hosted zones are arbitrary. The only thing to note is that the file name is the name that Cumulus will use to refer to your hosted zone in its output, and as input into its command line interface (minus the `.json`, of course). Zone definitions are JSON objects with the following attributes:

* `domain` - the domain name of your hosted zone, ie. `"example.com"`
* `private` - whether your hosted zone is private or not
* `comment` - a comment describing your hosted zone
* `zone-id` - the id of your hosted zone (this needs to be retrieved from the AWS console)
* `vpc` - if your hosted zone is private, you can associate VPCs with the zone. This parameter is an array of JSON objects with the following properties:
  * `id` - the id of the VPC to associate
  * `region` - the VPC's region, ie. `"us-east-1"`
* `records` - a JSON object containing record configuration in the following attributes:
  * `includes` - an array of files from which to include records (see [includes](#includes))
  * `ignored` - an array of regexes for record names to ignore (see [ignores](#ignores))
  * `inlines` - an array of record configurations (see [record definition](#record-definition))

Here's an example of a public zone definition:

{% highlight json %}
{
  "domain": "example.com",
  "zone-id": "Z23N6K3FTHCHPS",
  "private": false,
  "comment": "An example comment",
  "records": {
    "ignored": [ ... ],
    "includes": [ ... ],
    "inlines": [ ... ]
  }
}
{% endhighlight %}

And here's another example, this time of a private zone definition:

{% highlight json %}
{
  "domain": "example.com",
  "zone-id": "Z23N6K3FTHCHPS",
  "private": true,
  "comment": "An example comment",
  "vpc": [
    {
      "id": "vpc-5f019b3a",
      "region": "us-east-1"
    },
    ...
  ],
  "records": { ... }
}
{% endhighlight %}

It should be noted that Cumulus will not create hosted zones for you, because you need to manually configure any zone you create in Route53 with your domain registrar. As such, your zone definitions are only used to sync your Route53 configuration.

Record Definition
-----------------

Cumulus allows you to define two different types of records: basic and alias records. The following sections describe how to configure both types of records.

Currently Cumulus only supports Route53 [basic resource record sets](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-basic.html) and [alias resource record sets](http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-values-alias.html) because those are the record types that are used at Lucid. If you have additional needs, please submit a pull request!

### Basic

Basic records are just JSON objects with the following attributes:

* `name` - the name of the record. This value will be prepended to the domain of the hosted zone such that if `name` is `"sub"`, the final value will be `sub.domain.com`, and `""` will produce `domain.com`
* `type` - one of the record types allowed by Route53, ie. `A`, `TXT`, etc.
* `ttl` - the desired TTL for the record
* `value` - an array of values for the record, each of which will be a single line in the record. For `TXT` and `SPF` records, Cumulus will wrap each value in double quotes, just as Route53 expects, so you won't have to.

Here are a couple examples:

{% highlight json %}
[
  {
    "name": "sub",
    "type": "A",
    "ttl": 300,
    "value": [
      "127.0.0.1",
      "123.4.5.6"
    ]
  },
  {
    "name": "a",
    "type": "TXT",
    "ttl": 300,
    "value": [
      "Sample Text"
    ]
  }
]
{% endhighlight %}

### Aliases

Alias records are records that point to other AWS resources. Route53 allows you to point records at ELBs, S3 websites, CloudFront distributions, or other records within the Route53 zone. Alias records contain the following attributes:

* `name` - the name of the record. This attribute works just as it does for basic records.
* `type` - one of the record types allowed by Route53, ie. `A`, `TXT`, etc.
* `alias` - an object containing the following attributes:
  * `type` - the type of AWS resource to point to. Values include `"elb"`, `"s3"`, `"cloudfront"`, and `"record"`
  * `name` - the name of the AWS resource to point to. Should be omitted for s3 and cloudfront.

The alias name differs a little for each of the alias types:

* ELB - the alias name should be the name of the load balancer. Cumulus will look up the ugly DNS ELB name for you.
* S3 - the alias name should be omitted, as a Route53 record for an S3 website requires that the bucket name matches the record name.
* CloudFront - the alias name should be omitted, as a Route53 record for a CloudFront distribution requires that one of the aliases for the CloudFront distribution matches the record name.
* Record - the alias name should be the full name of the other record, ie. `"sub.domain.com"`

Here are examples of each type:

{% highlight json %}
[
  {
    "name": "a",
    "type": "A",
    "alias": {
      "type": "elb",
      "name": "elb-name"
    }
  },
  {
    "name": "b",
    "type": "A",
    "alias": {
      "type": "s3"
    }
  },
  {
    "name": "c",
    "type": "A",
    "alias": {
      "type": "cloudfront"
    }
  },
  {
    "name": "d",
    "type": "A",
    "alias": {
      "type": "record",
      "name": "sub.example.com"
    }
  }
]
{% endhighlight %}

### Includes

Sometimes you have multiple zones that contain the same records. In order to prevent someone from only changing records in one place and forgetting about the others (and thereby messing up your environment!), Cumulus allows you to define a file filled with common records that can be included in multiple zone definitions. The folder the includes are located in is [configurable](#configuration), but each file should contain a JSON array of [record definitions](#record-definition).

To use includes, add the names of the files you'd like to include into the `includes` array of your zone definition (minus the `.json` extension). For example:

{% highlight json %}
{
  ...
  "records": {
    "includes": [
      "example-included"
    ],
    ...
  }
}
{% endhighlight %}

In this example, the records in `example-included.json`, which should look something like

{% highlight json %}
[
  {
    "name": "a",
    "type": "TXT",
    "ttl": 300,
    "value": [
      "Sample Text"
    ]
  },
  ...
]
{% endhighlight %}

### Ignores

At Lucid, parts of our infrastructure automatically create Route53 records. We didn't want to manage these records as they are variable, so we wanted Cumulus to ignore those records. Perhaps you have something similar in your environment. To ignore records, add a regex string that will match the records you want to ignore to the `ignored` array of the zone definition. For example, if we wanted to ignore any records that have names that look like `example-1.domain.com`, `example-2.domain.com`, etc., we could use the following:

{% highlight json %}
{
  ...
  "records": {
    "ignored": [
      "^example-",
      ...
    ],
    ...
  }
}
{% endhighlight %}

Diffing and Syncing Route53
---------------------------

Cumulus's Route53 module has the following usage:

{% highlight bash %}
cumulus route53 [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Hosted zones can be diffed, listed, and synced (migration is covered in the [following section](#migration)). The three actions to the following:

* `diff` - Shows the differences between the local definition and the AWS Route53 configuration. If `<asset>` is specified, Cumulus will diff only the zone defined in that file.
* `list` - Lists the names of the files that contain hosted zone definitions
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the zone defined in the file with that name.

Migration
---------

If your environment is anything like ours, you have hundreds of records, and would rather not write Cumulus configuration for them by hand. Luckily, Cumulus provides a `migrate` task that will pull down your zones and produce configuration for them. Unfortunately, it won't pull records into common files for includes or produce ignores for you, so you'll still have to do that by hand, but it should be far less work.

Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the Route53 module:

* `$.route53.print-all-ignored` - if true, when diffing and syncing, Cumulus will print out each record that is ignored by your regexes. If false, Cumulus will just print out the number of ignored records. Defaults to `true`.
* `$.route53.zones.directory` - the directory where Cumulus expects to find zone definitions. Defaults to `conf/route53/zones`.
* `$.route53.includes.directory` - the directory where Cumulus expects to find includes. Defaults to `conf/route53/includes`.
