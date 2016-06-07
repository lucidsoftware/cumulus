---
layout: module
title: IAM
image: assets/img/iam.svg
description: Create and manage IAM groups, roles, users, and policies with configuration.
---
Overview
--------

The Cumulus IAM module defines IAM groups, roles, users, and policies with JSON files. Cumulus then syncs those configuration files with AWS to produce groups, roles and users. The module also provides the ability to generate Cumulus configuration from existing AWS IAMs to aid in migrating to Cumulus.

Cumulus has three different types of policy definitions. Inline policies are defined on the resource and are used to define a policy that will not be used elsewhere. If a policy will be used as is in multiple places, it should be defined as a static policy. Finally, a template policy can produce policies that differ only by the variables passed to the template. Additionally, AWS managed policies can be attached to resources in the resource definition. When creating policies for IAM resources, Cumulus merges all the JSON policy definitions into one inline policy in AWS to avoid hitting the character limit imposed by AWS.

Resource Definitions
--------------------

IAM resources are defined in JSON files that contain data about resources and include desired policies. All resources contain the following common values:

* `name`     - the name of the resource. This should match the filename.
* `policies` - an object containing the policies to include. This object is covered further in [the section on policy definitions](#policy-definitions)

Here's an example of an empty resource with the common attributes:

{% highlight json %}
{
  "name": "example-resource",
  "policies": {
    "attached": [],
    "static": [],
    "templates": [],
    "inlines": []
  }
}
{% endhighlight %}

The following sections will describe the unique properties of each resource type. Example configurations are included with the [Cumulus repo](https://github.com/lucidsoftware/cumulus).

### Group Definition

By default, group definitions are located in `{path-to-cumulus}/conf/iam/groups`, but this can be [configured](#configuration). In addition to the common resource values, groups contain the following unique properties:

* `users` - an array of user names who belong to the group. These user names refer to the names given to user resources.

Here is an example of a group (excluding the common configuration):

{% highlight json %}
{
  ...
  "users": [
    "example-user",
    ...
  ]
}
{% endhighlight %}

### Role Definition

By default, role definitions are located in `{path-to-cumulus}/conf/iam/roles`, but this can be [configured](#configuration). In addition to the common resource values, roles contain the following unique properties:

* `policy-document` - the filename of the "assume role document" required by AWS. These files are located in `{path-to-cumulus}/conf/iam/roles/policy-documents`, but this can be [configured](#configuration). Because most roles have the same assumption policy, this cuts down on duplicated configuration.

Here is an example of a role (excluding the common configuration):

{% highlight json %}
{
  ...
  "policy-document": "default"
}
{% endhighlight %}

### User Definition

By default, user definitions are located in `{path-to-cumulus}/conf/iam/users`, but this can be [configured](#configuration). User definitions contain no unique properties.

Policy Definitions
--------

### Inline Policies - One Off Policy Definition

Groups, roles, and users can all define single use policies in their resource definition. In the JSON object that defines the resource, just add an array named `inlines` and fill the array with AWS policy statements.

{% highlight json %}
// incomplete resource definition
{
  ...
  "policies": {
    "inlines": [
      {
        "Effect": "Deny",
        "Action": [
          "ec2:DescribeTags"
        ],
        "Resource": [
          "*"
        ]
      },
      ...
    ],
    ...
  }
  ...
}
{% endhighlight %}

### Static Policies - Reusable Policies

Policy declarations put in the static policy directory can be included as is in multiple resources. By default, static policy configuration is placed in `{path-to-cumulus}/conf/iam/policies/static`, but this can be [configured](#configuration). The JSON file contains a single AWS policy statement or an array of policy statements, like this:

{% highlight json %}
// defined in file example-static
[
  {
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeTags"
    ],
    "Resource": [
      "*"
    ]
  },
  ...
]
{% endhighlight %}

Once the policy has been defined in the file `example-static`, it can be included in resource definitions. All resource types must include an array named `static` containing the file names of the static policies. These names will not include the full path from the project root, just the name of the file:

{% highlight json %}
// incomplete resource definition
{
  ...
  "policies": {
    "static": [
      "example-static"
    ],
    ...
  },
  ...
}
{% endhighlight %}

### Template Policies - Templated Policies with Variables

Sometimes many resources have policies that are almost the same, except for slight differences, such as accessing different S3 buckets. This is a good use case for template policies. By default, template policy configuration is placed in `{path-to-cumulus}/conf/iam/policies/templates`, but this can be [configured](#configuration). The JSON file for a policy template contains a single AWS policy statement or an array of policy statements, with variables escaped by double curly braces:

{% highlight json %}
// defined in file example-template
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject"
  ],
  "Resource": [
    {% raw %}"arn:aws:s3:::{{bucket}}/*"{% endraw %}
  ]
}
{% endhighlight %}

When including the template in a resource definition, simply supply the value of the variable, and the variable will be replaced by the value in the policy. Resource definitions contain an array called `templates`, which contains objects that have the template name and an object called `vars` which defines the variables and their values. For example:

{% highlight json %}
// incomplete resource definition
{
  ...
  "policies": {
    "templates": [
      {
        "template": "example-template"
        "vars": {
          "bucket": "example"
        }
      },
      ...
    ],
    ...
  },
  ...
}
{% endhighlight %}

This definition will result in the resource containing the following statement in its policy:

{% highlight json %}
{
  "Effect": "Allow",
  "Action": [
    "s3:PutObject",
    "s3:GetObject"
  ],
  "Resource": [
    "arn:aws:s3:::example/*"
  ]
}
{% endhighlight %}

### Attached Policies - Using Managed Policies

IAMs provides the ability to attach up to two managed policies to a resource. In Cumulus, this can be configured by adding an array of ARNs called `attached` to the resource definition:

{% highlight json %}
// incomplete resource definition
{
  ...
  "policies": {
    "attached": [
      "arn:aws:iam::aws:policy/ReadOnlyAccess"
    ],
    ...
  },
  ...
}
{% endhighlight %}


Diffing and Syncing Configuration
---------------------------------

Cumulus's IAM module has the following usage:

{% highlight bash %}
cumulus iam [help|groups|roles|users] [diff|list|migrate|sync] <asset>
{% endhighlight %}

Each type of resource can be diffed, listed, and synced (migrate is covered in the [following section](#migration)). These three actions do the following with their respective resource type:

* `diff` - Shows the differences between the local definition and the AWS IAM configuration. If `<asset>` is specified, Cumulus will diff only the resource with that name.
* `list` - Lists the names of all the resources defined in local configuration
* `sync` - Syncs local configuration with AWS. Will not delete unmanaged resources or policies. If `<asset>` is specified, Cumulus will sync only the resource with that name.

Migration
---------

In order to make migrating to Cumulus less painful, the `migrate` command for each resource type will generate Cumulus configuration corresponding to existing AWS IAMs. While doing so, Cumulus will track the policies it encounters and, where possible, create static policies that can be reused. This automates some of the work of reducing duplication when migrating to Cumulus.

Configuration
-------------

Cumulus reads configuration from a configuration file, `conf/configuration.json` (the location of this file can also be specified by running cumulus with the `--config` option). The values in `configuration.json` can be changed to customized to change some of Cumulus's behavior. The following is a list of the values in `configuration.json` that pertain to the IAM module (in the list, `.` means the name after the `.` is inside of the object who's name appears on the left):

* `$.iam.groups.directory` - the directory where Cumulus expects to find group definitions. Defaults to `conf/iam/groups`
* `$.iam.roles.directory` - the directory where Cumulus expects to find role definitions. Defaults to `conf/iam/roles`
* `$.iam.roles.policy-document-directory` - the directory where Cumulus expects to find "assume role policy" documents. Defaults to `conf/iam/roles/policy-documents`
* `$.iam.users.directory` - the directory where Cumulus expects to find user definitions. Defaults to `conf/iam/users`
* `$.iam.policies.static.directory` - the directory where Cumulus expects to find static policies. Defaults to `conf/iam/policies/static`
* `$.iam.policies.templates.directory` - the directory where Cumulus expects to find template policies. Defaults to `conf/iam/policies/templates`
* `$.iam.policies.prefix` - the prefix that will be prepended to the name of the inline policy that Cumulus generates for a resource. Defaults to empty string
* `$.iam.policies.suffix` - the suffix that will be appended to the name of the inline policy that Cumulus generates for a resource. Defaults to `-generated`
* `$.iam.policies.version` - AWS IAM resources require a "Version". It doesn't seem to have any meaning, but must be one of a specific set of values. Defaults to `"2012-10-17"`
