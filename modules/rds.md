---
layout: module
title: RDS Instances
image: assets/img/rds.svg
description: Create and manage RDS instances
---
Overview
--------
Cumulus makes configuring RDS instances simpler. Read the following sections to learn about configuring your instances with Cumulus. Example configuration can be found in the [Cumulus repo](https://github.com/lucidsoftware/cumulus).


Instances
---------

Each managed RDS instance is defined in its own file where the file name is the name of the instance. These files are located in a [configurable](#configuration) folder. Instances created with Cumulus are automatically ran. After creation, Cumulus does not stop or terminate instances. Not all attributes of an instance can be updated, and some attributes require stopping an instance to take effect.

Instances are JSON objects with the following attributes:

* `port` - an integer value indicating what port the database service should be listening on.
* `type` - the type of instance to use. values such as "t2.micro", "m4.large", "m3.large", etc are accepted.
* `engine` - the engine type to use for the database. valid engine types are: "mysql", "mariadb", "oracle-se1", "oracle-se", "oracle-ee", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web", "postgres", "aurora"
* `engine_version` - this value is different for whatever engine is being used. it refers the release version of the engine to use.
* `storage_type` - the type of storage to use. can be either "standard", "gp2", or "io1"
* `storage_size` - the storage size to allocate for the database. must be an integer value
* `master_username` - the master username for the database. if given, a password will be required when the database is created
* `security-groups` - an array of security group names to attach to the database instance
* `subnet` - the db subnet group that the database instance is assigned to. this is different than vpc subnets
* `database` - the meaning of this parameter changes based on what database engine you use. it typically refers to the initial database name.
* `public` - boolean value indicating if the database is visible to the public
* `backup_period` - how long (in days) to keep backups for
* `backup_window` - the preferred time to perform backup operations
* `auto_upgrade` - boolean value indicating wether to perform minor version upgrades automatically
* `upgrade_window` - the preferred time to perform maintenance operations


Here is an example of an instance configuration:

{% highlight json %}
{
  "port": 3306,
  "type": "t2.micro",
  "engine": "mysql",
  "engine_version": "5.6.27",
  "storage_type": "gp2",
  "storage_size": 5,
  "master_username": "cumulususer",
  "security-groups": [
    "default",
  ],
  "subnet": "default",
  "database": "mydb",
  "public": false,
  "backup_period": 7,
  "backup_window": "02:27-02:57",
  "auto_upgrade": true,
  "upgrade_window": "mon:03:27-mon:03:57"
}
{% endhighlight %}


Diffing and Syncing Instances
------------------------------

Cumulus's RDS instances module has the following usage:

{% highlight bash %}
cumulus rds [help|list|migrate|diff|sync] <asset>
{% endhighlight %}

Instances can be diffed, listed, synced, and migrated. If the [ignore-unmanaged](#configuration) option is set, only instances that are already defined locally will be diffed and synced.

The four actions do the following:

* `diff` - Shows the differences between the local definition and the AWS instance configuration. If `<asset>` is specified, Cumulus will diff only the instance with that name.
* `list` - Lists the names of all of the locally defined instances
* `sync` - Syncs local configuration with AWS. If `<asset>` is specified, Cumulus will sync only the instance with that name
* `migrate` - Creates local json versions of your current AWS configuration in the `rds/instances` directory. Only migrates instances that have not been terminated and are not in an autoscaling group
