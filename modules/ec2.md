---
layout: module
title: EC2 Instances
image: assets/img/ec2.png
description: Create and manage EC2 instances
---
Overview
--------
Cumulus makes configuring EC2 instances simpler. The ec2 module has two sub-modules: instances and ebs. Read the following sections to learn about configuring your instances and EBS volumes with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).


Instances
---------

EC2 Instances are managed using the `instances` submodule. Each managed instance is defined in its own file where the file name is the name of the instance. These files are located in a [configurable](#configuration) folder. Instances created with Cumulus are automatically ran. After creation, Cumulus does not stop or terminate instances. Not all attributes of an instance can be updated, and some attributes require stopping an instance to take effect.

Instances are JSON objects with the following attributes:

* `ebs-optimized` - a boolean value indicating whether an instance is optimized for EBS volumes. Not available for all instances types, and the instance must be stopped to update this value.
* `placement-group` - optionally place an instance in the named Placement Group when creating the instance. Cannot be updated after creation
* `profile` - the ARN of the IAM instance profile for the instance. Cannot be updated after creation
* `image` - the AMI image id to launch the instance with. If not set, it will use the `default-image-id` specified in [configuration](#configuration). Cannot be updated after creation
* `key-name` - optionally supply the name of the SSH Key Pair to use to connect to the instance. Cannot be updated after creation
* `monitoring` - a boolean value indicating whether monitoring is enabled on the instance
* `network-interfaces` - the number of network interfaces to create and attach to the instance. Can only be updated to a higher value
* `source-dest-check` - a boolean value indicating whether or not source dest check is enabled on the instance. Also applies to the network interfaces on the instance
* `private-ip-address` - optionally specify the private ip address for the instance. If the instance only has one network interface, this will be the private ip address of that interface. If there are multiple network interfaces, it will not be specified on any of them. Cannot be updated after creation
* `security-groups` - an array of security group names for the instance. Also applies to the network interfaces on the instance.
* `subnet` - the name or id of the subnet to launch the instance in. Cannot be updated after creation
* `tenancy` - the tenancy of the instance. Accepts `"default"` and `"dedicated"`. Cannot be updated after creation
* `type` - the EC2 instance type. Cannot be updated after creation.
* `user-data` - the name of the user data script to run. The script is located in a [configurable](#configuration) folder. Cannot be updated after creation
* `volume-groups` - an array of the names of volume groups to attach to the instance. See [Volume Groups](#volume-gorups) for more information

Here is an example of an instance configuration:

{% highlight json %}
{
  "ebs-optimized": false,
  "placement-group": null,
  "profile": "example-instance-profile",
  "image": null,
  "key-name": null,
  "monitoring": false,
  "network-interfaces": 1,
  "source-dest-check": false,
  "private-ip-address": null,
  "security-groups": [
    "default"
  ],
  "subnet": "example-subnet",
  "tenancy": "default",
  "type": "t2.micro",
  "user-data": null,
  "volume-groups": [
    "example-group"
  ]
}
{% endhighlight %}


Volume Groups
-------------

EBS Volumes are a commonly used EC2 resource that is actually difficult to use with the AWS web console. Cumulus provides an `ebs` sub-module to the ec2 module which allows you to easily manage EBS volumes in what we call volume groups. Each volume group contains configuration for the EBS volumes in that group. Volume groups make it easy to keep track of which volumes are attached to which instance, and makes it very easy to add new volumes to an instance. Cumulus will never delete or detach volumes. Volume Group configurations are stored in a [configurable](#configuration) directory. When syncing the `volume-groups` attribute on an instance, volumes will be mounted at the next available slot according to [configuration](#configuration)

Volume Groups are JSON objects with the following attributes:

* `availability-zone` - the name of the availability zone the EBS volumes will be created in. Cannot be updated after creation
* `volumes` - an array of JSON objects describing what volumes are in the group. Each object has the following properties:
  * `size` - the size (in GiB) of the desk
  * `type` - the type of the disk. Accepted values are standard, io1, gp2
  * `iops` - if type is io1, the number of iops to provision for the disk
  * `encrypted` - whether or not the disks will be encrypted
  * `kms-key` - if encrypted, the kms key to use to encrypt the disk. If encrypted and not specified, uses the default key
  * `count` - the number of disks with this configuration. This is the only property that can be incrementally updated to add more of the same-configured disk. Updating other properties will create "count" number of the new disk configuration.

Here is an example of a volume group configuration that has 1 32GiB standard disk and 4 16GiB gp2 disks

{% highlight json %}
{
  "availability-zone": "us-east-1a",
  "volumes": [
    {
      "size": 32,
      "type": "standard",
      "encrypted": false,
      "count": 1
    },
    {
      "size": 16,
      "type": "gp2",
      "count": 4,
      "encrypted": false
    }
  ]
}
{% endhighlight %}


Diffing and Syncing Instances
------------------------------

Cumulus's EC2 instances module has the following usage:

{% highlight bash %}
cumulus ec2 instances [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Instances can be diffed, listed, synced, and migrated. If the [ignore-unmanaged](#configuration) option is set, only instances that are already defined locally will be diffed and synced. Additionally, Cumulus ignores any instances that are managed in an autoscaling group.

The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS instance configuration. If `<asset>` is specified, Cumulus will diff only the instance with that name.
* `list` - Lists the names of all of the locally defined instances
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the instance with that name
* `migrate` - Creates local json versions of your current AWS configuration in the `ec2/instances` directory. Only migrates instances that have not been terminated and are not in an autoscaling group


Diffing and Syncing Volume Groups
---------------------------------

Cumulus's EC2 ebs module has the following usage:

{% highlight bash %}
cumulus ec2 ebs [diff|help|list|migrate|sync] <asset>
{% endhighlight %}

Volume groups can be diffed, listed, synced, and migrated. The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS instance configuration. If `<asset>` is specified, Cumulus will diff only the volume group with that name.
* `list` - Lists the names of all of the locally defined volume groups
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the volume group with that name
* `migrate` - Creates local json versions of your current AWS configuration in the `ec2/ebs` directory. Only attached volumes are migrated. Any root-mounted volumes will not be included in any volume group. Any volumes not already in a group will be assigned to a group with the name of the instance they are attached to. While migrating, Cumulus will prompt the user if they want to update the EBS volumes in AWS with the Group tag so they can be immediately diffed and synced without more manual configuration (highly recommended).

Configuration
-------------
Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the EC2 module:

* `$.ec2.ebs.directory` - the directory where Cumulus expects to find volume group definitions. Defaults to `conf/ec2/ebs`.
* `$.ec2.instances.directory` - the directory where Cumulus expects to find instance definitions. Defaults to `conf/ec2/instances`.
* `$.ec2.instances.user-data-directory` - the directory where Cumulus expects to find user data scripts. Defaults to `conf/ec2/user-data`
* `$.ec2.instances.ignore-unmanaged` - if true, then Cumulus will ignore any instances that are not defined locally when diffing.
* `$.ec2.instances.default-image-id` - if set, this is the default image id that will be used when creating instances if one is not specified in the instance configuration. Recommended if most of your instances are launched from the same image
* `$.ec2.instances.volume-mounting.base` - the base directory to mount ebs volumes at. Defaults to `/dev/xvd`
* `$.ec2.instances.volume-mountaing.start` - the starting letter to mount volumes at. This is appended to `volume-mounting.base` to get the full mount path. Defaults to `f`
* `$.ec2.instances.volume-mounting.end` - the highest letter that a volume can be mounted at. When creating an instance, only a number of volumes that fit between the start and end letter can be attached or an error is thrown. Defaults to `z`