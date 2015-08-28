---
layout: module
title: CloudFront
image: assets/img/cloudfront.png
description: Create and manage CloudFront web distributions and run invalidations
---
Overview
--------
Cumulus makes using CloudFront easier and cleaner! Easily configure web distributions and update cache behaviors! Run commonly used invalidations! Read the following sections to learn about configuring your CloudFront environment with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

Distribution Definition
-----------------------

Cumulus currently only supports managing CloudFront [Web Distributions](http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web.html) because these are the only distributions we use at this time at Lucid. If you have additional needs, submit a pull request!

Each distribution is defined in its own file, and the folder distributions are located in is [configurable](#configuration). In other Cumulus modules, you've probably seen that managed assets get their names from the names of the files in which they are defined. However, because CloudFront distributions are only identifiable by their ID in AWS, file names for distributions are arbitrary. The only thing to note is that the file name is the name that Cumulus will use to refer to your distribution in its output, and as input into its command line interface (minus the `.json`, of course). Distributions are JSON objects with the following attributes:

* `id` - the id of your distribution. If omitted, a new distribution will be created with the configuration
* `aliases` - an optional array of CNAMEs that alias your distribution
* `origins` - an array of at least one JSON object defining the origin(s) for your distribution. Origins have the following properties:
  * `id` - the id of the origin
  * `domain-name` - the domain name for the origin e.g. `"www.example.com"`
  * `origin-path` - the path in the origin that CloudFront will serve from
  * `s3-origin-access-identity` - if the origin is S3, this must be defined with the s3 origin access identity or an empty string `""`
  * `custom-origin-config` - if the origin is not s3, this will contain a JSON object with the following properties:
    * `http-port` - the http port for the custom origin
    * `https-port` the https port for the custom origin
    * `protocol-policy` - the policy to use when serving content from the origin valid values include `"http-only"` and `"match-viewer"`
* `default-cache-behavior` - a JSON object that defines how items from an origin may be cached in CloudFront when a request matches no other cache behavior. see [Cache Behaviors](#cache-behaviors) for details on how it is configured.
* `cache-behaviors` - an optional array of JSON objects defining the cache behaviors this distribution has. The order these behaviors are defined is the order in which they are checked to see if a requests matches. The properties of the JSON object are discussed in [Cache Behaviors](#cache-behaviors)
* `comment` - the comment describing your distribution
* `enabled` - a true/false value indicating if your distribution is enabled

Here is an example of a distribution with a custom origin:

{% highlight json %}
{
  "id": "DistributionID",
  "origins": [
    {
      "id": "Custom-www.example.com",
      "domain-name": "www.example.com",
      "origin-path": "/cloudfronted",
      "custom-origin-config": {
        "http-port": 80,
        "https-port": 443,
        "protocol-policy": "match-viewer"
      }
    }
  ],
  "default-cache-behavior": {...},
  "comment": "Created with Cumulus",
  "enabled": false
}
{% endhighlight %}

### Cache Behaviors

A cache behavior controls how itemes accessed using the distribution are cached. Cache Behaviors have the following properties:

* `target-origin-id` - the ID of the origin this cache behavior will apply to e.g. `"www.example.com"`
* `path-pattern` - the pattern the path of the request must have to use this cache behavior e.g. `"*.txt"`. Paths that do not match will use the `default-cache-behavior` configuration.  When configuring the `default-cache-behavior` this property should be left out or set to `null`
* `forward-query-strings` - a true/false value indicating if query strings will be forwarded to the origin. If false, requests to `object1` and `object1?a=b` will serve the same response
* `forwarded-cookies` - defines which cookies will be forwarded to the origin. Valid values are `"none"`, `"whitelist"` and `"all"`
* `forwarded-cookies-whitelist` - if `forwarded-cookies` is `"whitelist"` this array will determine which cookies are forwarded to the origin. Otherwise, this can be left empty or omitted
* `forward-headers` - an array of header names that are forwarded to the origin e.g. `["Authorization", "Origin"]`
* `trusted-signers` - an array of trusted signers that can sign content delivered by cloudfront. If omitted or empty, will disable trusted signing for this cache behavior
* `viewer-protocol-policy` - the policy to enforce on a viewer for this cache behavior. Valid values include `"allow-all"`, `"https-only"`, and `"redirect-to-https"`
* `min-ttl` - the minimum TTL (in seconds) a cached item in this behavior will have, regardless of what is specified on the item e.g. `0`
* `default-ttl` - the default TTL (in seconds) a cached item in this behavior will have if it is not specified on the item
* `max-ttl` - the maximum TTL (in seconds) a cached item in this behavior will have, regardless of what is specified on the item
* `smooth-streaming` - a true/false value indicating if smooth streaming is enabled for this behavior
* `allowed-methods` - an array defining the HTTP methods that are allowed in this behavior. Methods can include `"HEAD"`, `"GET"`, `"POST"`, `"PUT"`, `"OPTIONS"`, `"DELETE"`, and `"PATCH"`
* `cached-methods` - a subset of `allowed-methods` defining the HTTP methods that are cached in this behavior

Here is an example cache behavior configuration that could be used for the `default-cache-behavior`:

{% highlight json %}
{
  "target-origin-id": "Custom-www.example.com",
  "forward-query-strings": true,
  "forwarded-cookies": "whitelist",
  "forwarded-cookies-whitelist": [
    "SESSION",
  ],
  "forward-headers": [
    "Origin"
  ],
  "trusted-signers": [
    "self"
  ],
  "viewer-protocol-policy": "https-only",
  "min-ttl": 0,
  "max-ttl": 31536000,
  "default-ttl": 86400,
  "smooth-streaming": false,
  "allowed-methods": [
    "HEAD",
    "GET",
    "OPTIONS"
  ],
  "cached-methods": [
    "HEAD",
    "GET"
  ]
}
{% endhighlight %}

Here is a full example of a distribution config with an S3 origin and another cache behavior which caches all .PNG requests for a year, and other requests for a day

{% highlight json %}
{
  "id": "DistributionID",
  "origins": [
    {
      "id": "S3-bucket-name-1",
      "domain-name": "bucket-name-1.s3.amazonaws.com",
      "origin-path": ""
    }
  ],
  "default-cache-behavior": {
    "target-origin-id": "S3-bucket-name-1",
    "forward-query-strings": false,
    "forwarded-cookies": "none",
    "forward-headers": [],
    "trusted-signers": [],
    "viewer-protocol-policy": "https-only",
    "min-ttl": 86400,
    "max-ttl": 86400,
    "default-ttl": 86400,
    "smooth-streaming": false,
    "allowed-methods": [
      "HEAD",
      "GET",
      "OPTIONS"
    ],
    "cached-methods": [
      "HEAD",
      "GET"
    ]
  },
  "cache-behaviors": [
    {
      "target-origin-id": "S3-bucket-name-1",
      "path-pattern": "*.png",
      "forward-query-strings": false,
      "forwarded-cookies": "none",
      "forward-headers": [],
      "trusted-signers": [],
      "viewer-protocol-policy": "https-only",
      "min-ttl": 31536000,
      "max-ttl": 31536000,
      "default-ttl": 31536000,
      "smooth-streaming": false,
      "allowed-methods": [
        "HEAD",
        "GET",
        "OPTIONS"
      ],
      "cached-methods": [
        "HEAD",
        "GET",
        "OPTIONS"
      ]
    }
  ],
  "comment": "Created with Cumulus",
  "enabled": false
}
{% endhighlight %}

It should be noted that Cumulus will create a new CloudFront distribution if you omit the `"id"` parameter the next time the configuration is synced. After creation, the configuration used to create the distribution will be updated with the id of the created distribution to prevent it from being created again on accident.

There are some configuration options for web distributions that Cumulus does not handle because we do not use them at Lucid or do not want them managed by Cumulus at this time. These include:

* `default_root_object`
* `logging`
* `price_class`
* `viewer_certificate`
* `restrictions`

If you would like these added to Cumulus, please submit a pull request.


Diffing and Syncing CloudFront
------------------------------

Cumulus's CloudFront module has the following usage:

{% highlight bash %}
cumulus cloudfront [diff|help|invalidate|list|migrate|sync] <asset>
{% endhighlight %}

Distributions can be diffed, listed, and synced, and invalidated (migration is covered in the [following section](#migration)). The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS CloudFront configuration. If `<asset>` is specified, Cumulus will diff only the distribution defined in that file.
* `list` - Lists the names of the files that contain distribution definitions
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the distribution defined in the file with that name.
* `invalidate` - Creates an invalidation based on the config specified by `<asset>`.  Information can be found in the [invalidation section](#invalidation)

Migration
---------

If your environment is anything like ours, you have dozens of distributions, and would rather not write Cumulus configuration for them by hand. Luckily, Cumulus provides a `migrate` task that will pull down your web distributions and produce configuration for them.

Invalidation
------------

Cumulus supports creating CloudFront invalidations using files in the [configurable](#configuration) invalidations directory.  Invalidations use a combination of the current time,  name of the file, and md5 of the specified paths to ensure that an invalidation on a distribution is not ran more than once in a 5 minute window. This is to prevent accidentally creating invalidations in quick succession, and can be easily overridden by changing the name of the file containing the invalidation config, changing the paths to invalidate, or waiting for the next 5 minute window. For example, if an invalidation was run at 1:49, it could not be ran again until 1:50 unless you changed the paths or renamed it.

Invalidation configurations are JSON objects with the following attributes:
* `distribution-id` - the id of the cloudfront distribution to run an invalidation on
* `paths` - an array of paths to invalidate on the distribution. Items must start with a `/` and may contain the wildcard `*` e.g. `["/*.jpg", "/index.html"]`

To run an invalidation that has been saved under `invalidations/invalidate-bucket-2.json` you would run the command:

{% highlight bash %}
cumulus cloudfront invalidate invalidate-bucket-2
{% endhighlight %}

Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the CloudFront module:

* `$.cloudfront.distributions.directory` - the directory where Cumulus expects to find distribution definitions. Defaults to `conf/cloudfront/distributions`.
* `$.cloudfront.invalidations.directory` - the directory where Cumulus expects to find invalidations. Defaults to `conf/cloudfront/invalidations`.
