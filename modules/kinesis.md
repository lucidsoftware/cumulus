---
layout: module
title: Kinesis
image: assets/img/kinesis.png
description: Create and manage Kinesis Streams
---
Overview
--------
Cumulus makes configuring Kinesis streams simpler. Read the following sections to learn about configuring your streams with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).


Streams
---------------------

Each stream is defined in its own file where the file name is the name of the stream. These files are located in a [configurable](#configuration) folder. Streams are JSON objects with the following attributes:

* `retention-period` - the amount of time (in hours) that data will be retained in a stream. Defaults to 24 hours, and valid values are in the range of [24,168]
* `shards` - the number of shards in the stream. When creating a stream, this must be greater than 0. When updating a stream, Cumulus only allows you to either double or halve the number of shards in a stream. For more information on updating the number of shards see [Shards](#shards)
* `tags` - an optional JSON object whose key/value pairs correspond to tag keys and values for the stream e.g. `{ "TagName": "TagValue" }`

Here is an example of a stream configuration:

{% highlight json %}
{
  "retention-period": 24,
  "shards": 1,
  "tags": {
    "Key1": "Value1"
  }
}
{% endhighlight %}


Shards
------

After creating a stream, the number of shards in a stream can only be changed by splitting and merging shards. Since Cumulus has no way of knowing how much throughput your stream needs, caution should be taken when updating the number of shards. Cumulus allows you to either double or halve the number of shards in a stream in an effort to keep the size of shards balanced. When you double the number of shards, each shard is split in half. When you halve the number of shards, each pair of adjacent shards is merged into a single shard. If this does not meet your needs you can still use the AWS API directly to perform shard splits and merges to suit your needs, and then just update the `shards` in your config without doing a sync.


Diffing and Syncing Streams
------------------------------

Cumulus's Kinesis module has the following usage:

{% highlight bash %}
cumulus kinesis [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Streams can be diffed, listed, synced, and migrated. The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS stream configuration. If `<asset>` is specified, Cumulus will diff only the stream with that name.
* `list` - Lists the names of all of the locally defined streams
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the stream with that name.
* `migrate` - Creates local json versions of your current AWS configuration in the `kinesis` directory


Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the Kinesis module:

* `$.kinesis.directory` - the directory where Cumulus expects to find stream definitions. Defaults to `conf/kinesis`.