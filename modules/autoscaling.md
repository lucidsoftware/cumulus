---
layout: module
title: Autoscaling Groups
image: assets/img/autoscaling.svg
description: Create and manage autoscaling groups, scheduled actions, scaling policies and policy alarms with configuration.
---
Overview
--------

The Cumulus Autoscaling module defines autoscaling groups, scheduled scaling actions, scaling policies and policy alarms in JSON files. Cumulus syncs those configuration files with AWS to create and manage autoscaling resources.

Cumulus has three different types of policy definitions. Inline policies are defined on the resource and are used to define a policy that will not be used elsewhere. If a policy will be used as is in multiple places, it should be defined as a static policy. Finally, a template policy can produce policies that differ only by the variables passed to the template.

The following sections will describe the unique properties of each resource type. Example configurations are included with the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

### Autoscaling Groups

An autoscaling group definition is just a JSON object. By default, the definitions are located in `{path-to-cumulus}/conf/autoscaling/groups`, but this can be [configured](#configuration). The JSON object can contain the following attributes (most of which are analogous to AWS configuration of autoscaling groups):

* `cooldown-seconds` - the integer number of seconds that should be the minimum time between scaling actions
* `enabled-metrics` - an array of metric names to enable. See <a href="http://docs.aws.amazon.com/sdkforruby/api/Aws/AutoScaling/Client.html#enable_metrics_collection-instance_method" target="_blank">the AWS documentation for a list of possible values</a>.
* `health-check-type` - a string defining the type of health check to perform. Value should be either `ELB` or `EC2`.
* `health-check-grace-period` - the number of seconds after an instance comes into service during which health check failures are ignored.
* `launch-configuration` - the name of the launch configuration to use
* `load-balancers` - an array of the names of load balancers to assign this autoscaling group to
* `policies` - a JSON object defining the scaling policies to attach to the autoscaling group. Details are in a [later section](#scaling-policies).
* `scheduled` - an array of JSON objects, each describing a scheduled scaling action. More details in the [next section](#scheduled-scaling-actions).
* `size` - a JSON object containing the following attributes that have to do with group size. These attributes are not necessarily the values that will be used when diffing or syncing. See [Syncing Size](#syncing-size) for more information
  * `min` - the minimum number of instances in the autoscaling group
  * `max` - the maximum number of instances in the autoscaling group
  * `desired` - the desired number of instances in the autoscaling group. If not set, `desired` will bet set to `min` when creating the autoscaling group
* `subnets` - an array of the subnets the autoscaling group should belong to
* `tags` - a JSON object who's keys and values will be used as tags for the autoscaling group
* `termination` - an array of the termination policies that should be applied to the autoscaling group. Amazon provides a <a href="http://docs.aws.amazon.com/AutoScaling/latest/DeveloperGuide/AutoScalingBehavior.InstanceTermination.html#custom-termination-policy" target="_blank">list of termination policies</a>.

### Scheduled Scaling Actions

An autoscaling group can be configured such that scaling actions take place on a scheduled basis. Scheduled scaling actions change the min, max, and desired number of instances in the autoscaling group. When syncing autoscaling groups that have scheduled actions, the size of the group may depend on what is configured in a scheduled action (see [Syncing Size](#syncing-size) for more information). Each scheduled scaling action is a JSON object in the `scheduled` array of the autoscaling group definition, and contains the following attributes:

* `name` - the name of the scheduled action
* `start` - the starting time of the scheduled action in "YYYY-MM-DDThh:mm:ssZ" format
* `end` - the ending time of the scheduled action in "YYYY-MM-DDThh:mm:ssZ" format
* `recurrence` - a <a href="https://en.wikipedia.org/wiki/Cron" target="_blank">cron</a> string defining the schedule for recurring actions
* `min` - what to set the minimum instances to
* `max` - what to set the maximum instances to
* `desired` - what to set the desired instances to

### Scaling Policies

Scaling policies specify scaling actions that can be taken on the autoscaling group. They are defined in JSON objects containing the following attributes:

* `name` - the name of the scaling policy
* `adjustment-type` - type of adjustment this policy makes to the autoscaling group. Valid values are `ChangeInCapacity`, `ExactCapacity`, and `PercentChangeInCapacity`.
* `adjustment` - the amount to scale by. The meaning of this number is determined by `adjustment-type`.
* `cooldown` - the number of seconds to wait after this scaling action is taken before taking any other scaling action
* `alarms` - an array of alarm definitions. Further details in [the section about alarms](#policy-alarms)

The `policies` attribute of autoscaling group definitions is a JSON object that contains three attributes: `inlines`, `templates`, and `static`. Each corresponds to a different method for specifying scaling policies.

* `inlines` is an array of JSON objects that directly define scaling policies. These are one off policy definitions.
* `static` is an array of names of files that contain scaling policy definition objects. By default, the definitions are located in `{path-to-cumulus}/conf/autoscaling/policies/static`, but this can be [configured](#configuration).
* `templates` is an array of JSON objects that contain a template name and the variables to apply to the template. By default, the template definitions are located in `{path-to-cumulus}/conf/autoscaling/policies/template`, but this can be [configured](#configuration). Variables in template files are surrounded by double curly braces. The objects that define their consumption contain a `template` attribute, which is the name of the template to use, and `vars`, a JSON object that maps variable names to the value to replace, likewise:

{% highlight json %}
{
  "template": "example-template",
  "vars": {
    "n": "2"
  }
}
{% endhighlight %}

### Policy Alarms

Scaling policies can contain alarms. Alarms correspond to Cloudwatch alarms, and will take the action defined by the autoscaling policy when the alarm is fired. Alarms are defined in JSON objects with the following attributes:

* `name` - the name of the alarm
* `description` - a human readable description of the alarm
* `actions-enabled` - whether this alarm is currently enabled
* `action-states` - an array of the alarm states that will trigger this policy. Valid values are `alarm`, `insufficient-data`, and `ok`
* `metric` - the metric the alarm should use
* `metric` - the namespace for the alarm's associated metric
* `statistic` - the statistic to use when checking the metric. Values are `SampleCount`, `Average`, `Sum`, `Minimum`, and `Maximum`
* `dimensions` - a JSON object used to specify the dimensions for the metric. Each key value pair in the object will be a dimension, with key as the name of the dimension and the value as the dimension's value.
* `period-seconds` - the number of seconds comprising a period over which the statistic is applied
* `evaluation-periods` - the number of consecutive periods needed to change the state of the alarm
* `threshold` - the number to compare against
* `unit` - the unit for the metric. See <a href="http://docs.aws.amazon.com/sdkforruby/api/Aws/CloudWatch/Client.html#put_metric_alarm-instance_method" target="_blank">AWS documentation</a> for a full list of units.
* `comparison` - the type of comparison to do with the threshold and statistic. Valid values are `GreaterThanOrEqualToThreshold`, `GreaterThanThreshold`, `LessThanThreshold`, `LessThanOrEqualToThreshold`

### Diffing and Syncing Configuration

Cumulus's autoscaling module has the following usage:

{% highlight bash %}
cumulus autoscaling [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Autoscaling groups can be diffed, listed, and synced (migrate is covered in [migration](#migration)). These three actions do the following:

* `diff` - Shows the differences between the local definition and the AWS autoscaling configuration. If `<asset>` is specified, Cumulus will diff only the autoscaling group with that name.
* `list` - Lists the names of all the autoscaling groups defined in local configuration
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the autoscaling group with that name.


### Syncing Size

Because autoscaling groups can change in size in response to alarms or scheduled actions, the size (min, max, and desired instances) of an autoscaling group is synced a little differently than the other configuration options. If the local configuration has any scheduled actions configured, we will set the min and max size of the autoscaling group to match the last scheduled action that would have ran. Desired is never updated unless it is not in the min/max bounds. This behavior can be overridden by passing the `--autoscaling-force-size` argument with the sync command, which will use the configured size on the autoscaling group instead of the most recent scheduled action.

For example, suppose we have an autoscaling group configured as follows:

{% highlight json %}
{
  ...
  "scheduled": [
    {
      "name": "Scale up at 9am UTC",
      "recurrence": "0 9 * * *",
      "min": 9
    }
  ],
  "size": {
    "min": 3,
    "max": 21,
    "desired": 4
  }
  ...
}
{% endhighlight %}

If the current time is 10am UTC, we will use a `min` value of 9, a `max` value of 21, and a `desired` value of 9 when comparing the local configuration to AWS configuration. Notice that if the `desired` value in AWS is outside of the new range, it will be updated to be within the range by raising the value to the `min` or lowering it to the `max`. If using the `--autoscaling-force-size` argument when diffing or syncing, the values of 3, 21, and 4 will be used for `min`, `max`, and `desired` respectively.

### Migration

Cumulus provides a `migrate` task that makes migrating to Cumulus easy. Autoscaling configuration is pulled down to produce Cumulus configuration. All scaling policies are converted to inline policies.

***IMPORTANT*** - because Cumulus assumes that the action taken by the alarm is triggering the policy, if you add another action to the alarm from the AWS console, it will be deleted when Cumulus syncs autoscaling. This is particularly important when migrating, as your previous configuration may have a single Cloudwatch alarm triggering a scaling policy, as well as taking some other action, like SNS notifications. In this case, if you wish to keep the other actions, it is recommended that you create a separate alarm for the other actions.

### Configuration

Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the Autoscaling module:

* `$.autoscaling.groups.directory` - the directory where Cumulus expects to find autoscaling group definitions. Defaults to `conf/autoscaling/groups`
* `$.autoscaling.groups.override-launch-config-on-sync` - whether to change the launch configuration when syncing a group, or show differences in launch configuration when diffing a group. If set to false, changing the launch configuration will need to be done from the AWS console. Defaults to `false`
* `$.autoscaling.policies.static.directory` - the directory where Cumulus expects to find static scaling policy definitions. Defaults to `conf/autoscaling/policies/static`
* `$.autoscaling.policies.templates.directory` - the directory where Cumulus expects to find scaling policy templates. Defaults to `conf/autoscaling/policies/templates`
