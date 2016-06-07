---
layout: module
title: SQS
image: assets/img/sqs.svg
description: Create and manage SQS Queues
---
Overview
--------
Cumulus makes configuring SQS queues simpler. Read the following sections to learn about configuring your queues with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).


Queues
---------------------

Each queue is defined in its own file where the file name is the name of the queue. These files are located in a [configurable](#configuration) folder. Queues are JSON objects with the following attributes:

* `delay` - the number of seconds that delivery of all messages in the queue will be delayed. Can range from 0 to 900 (15 minutes)
* `max-message-size` - the maximum size (in bytes) a message sent in the queue can be. Can range from 1024 (1 KiB) to 262144 (256 KiB)
* `message-retention` - the number of seconds SQS will retain a message in the queue. Can range from 60 (1 minute) to 1209600 (14 days)
* `receive-wait-time` - the number of seconds that a `ReceiveMessage` call will wait for a message to arrive. Can range from 0 to 20
* `visibility-timeout` - the number of seconds for the visiblity timeout of the queue, which is the amount of time that must pass before a message can be received in succession if it has not been deleted.  Can range from 0 to 43200 (12 hours)
* `dead-letter` - an optional JSON object configuring the dead letter queue functionality for the queue
  * `target` - the name of the queue that dead letter messages will be sent to
  * `max-receives` - the number of times a message must be received before it is considered a dead letter
* `policy` - the optional name of the policy file to use for the queue. If omitted, an empty policy will be used. See [Policies](#policies) for more information on configuring policies

Here is an example of a queue configuration:

{% highlight json %}
{
  "delay": "0",
  "max-message-size": "262144",
  "message-retention": "345600",
  "receive-wait-time": "0",
  "visibility-timeout": "30",
  "dead-letter": {
    "target": "example-queue-2",
    "max-receives": 3
  },
  "policy": "example-policy"
}
{% endhighlight %}


### Policies

The SQS API allows you to specify a policy when configuring a queue. These policies are in the same format as [IAM policies]({{ site.baseurl }}/modules/iam.html#policy-definitions) and are stored in a [configurable](#configuration) policies directory

Here is an example of a policy which allows another AWS account to send a message to `example-queue`

{% highlight json %}
{
  "Version": "2008-10-17",
  "Id": "example-ID",
  "Statement": [
    {
      "Sid": "example-statement-ID",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SQS:SendMessage",
      "Resource": "arn:aws:sqs:us-east-1:OTHER_ACCOUNT_ID:example-queue"
    }
  ]
}
{% endhighlight %}

For more information see the [IAM module]({{ site.baseurl }}/modules/iam.html)


Diffing and Syncing Queues
------------------------------

Cumulus's SQS module has the following usage:

{% highlight bash %}
cumulus sqs [diff|help|list|migrate|sync|urls] <asset>
{% endhighlight %}

Queues can be diffed, listed, synced, and migrated. The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS queue configuration. If `<asset>` is specified, Cumulus will diff only the queue with that name.
* `list` - Lists the names of all of the locally defined queues
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the queue with that name.
* `migrate` - Creates local json versions of your current AWS configuration in the `sqs` directory
* `urls` - Lists the names of all of the locally defined queues, and the URL of that queue if it also exists in AWS


Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the SQS module:

* `$.sqs.queues.directory` - the directory where Cumulus expects to find queue definitions. Defaults to `conf/sqs/queues`.
* `$.sqs.policies.directory` - the directory where Cumulus expects to find policy definitions. Defaults to `conf/sqs/policies`.
