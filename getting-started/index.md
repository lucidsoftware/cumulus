---
layout: getting-started
title: Getting Started
header-title: Getting Started with Cumulus
---
### Installing Cumulus

Cumulus can be installed through the `cumulus-aws` gem:

{% highlight bash %}
gem install cumulus-aws
{% endhighlight %}

Once installed, you'll be able to use the `cumulus` command. To get autocomplete for Cumulus, copy the [autocomplete file in the root of the Cumulus repo](https://github.com/lucidsoftware/cumulus/blob/master/autocomplete) to `/etc/bash_completion.d/cumulus`.

You'll also need to configure your AWS credentials locally, as described in [AWS's documentation](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#cli-config-files). If you've used the AWS CLI, you've probably already configured your credentials.

Cumulus is divided into modules, each of which manages a different part of your AWS architecture. As such, you can start using Cumulus one module at a time (or even just leave certain products unmanaged).

### Migrating to Cumulus
Of course, having to write configuration for all your existing AWS resources can be daunting tedious. Luckily, each Cumulus provides a migration task that will query your current architecture and create matching Cumulus configuration. That way you can get started with Cumulus without a huge time investment!

### Running Cumulus

Cumulus is run as follows:

{% highlight bash %}
cumulus <module> <command>
{% endhighlight %}

Each module, and their commands, are documented on this site. However all modules expose the following commands:

* `diff` - check for differences between your configuration and your actual architecture
* `sync` - change your AWS architecture to match your Cumulus configuration
* `migrate` - generate Cumulus configuration from your current architecture

When syncing, Cumulus chooses to be non-destructive, that is, it will not remove resources from AWS when they are not in your configuration (for example, if you have an EC2 instance that's not configured in Cumulus, it won't be removed on `sync`). This is one of the principal differences between Cumulus and Cloudformation.

Additionally, Cumulus supports the following options:

* `-c`, `--config` - specify the directory to use when getting Cumulus's `configuration.json` file. If this is not specified, it defaults to your current working directory
* `-p`, `--profile` - specify the name of the AWS profile to use for API requests
* `-v`, `--verbose` - allow verbose output
* `-r`, `--assume-role` - specify the name of the IAM role to assume when making API requests
* `--help` - print out the list of modules and all options

### Cumulus Configuration

Cumulus is configured by creating JSON files that describe your AWS architecture. Cumulus requires a JSON file called `configuration.json` that describes some global configuration options, but from there, each module defines its own JSON files. Descriptions of those files can be found in the documentation for each module, and examples can be found in [the Cumulus repo](https://github.com/lucidsoftware/cumulus/tree/master/conf).
