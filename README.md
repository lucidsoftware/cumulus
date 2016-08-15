# cumulus

[![Join the chat at https://gitter.im/lucidsoftware/cumulus](https://badges.gitter.im/lucidsoftware/cumulus.svg)](https://gitter.im/lucidsoftware/cumulus?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Stories in Ready](https://badge.waffle.io/lucidsoftware/cumulus.png?label=ready&title=Ready)](https://waffle.io/lucidsoftware/cumulus) [![Gem Version](https://badge.fury.io/rb/lucid-cumulus.svg)](https://badge.fury.io/rb/lucid-cumulus) [![Build Status](https://travis-ci.org/lucidsoftware/cumulus.svg?branch=master)](https://travis-ci.org/lucidsoftware/cumulus)

CloudFormation alternative

### Installation

To install cumulus, open a terminal and type:
```bash
gem install lucid-cumulus
```
Optionally, you can set up auto-completion by copying the autocomplete file in the root of the Cumulus repo to /etc/bash_completion.d/cumulus


### Usage

To run cumulus,
```
cumulus <module> <action>
```

For details, run
```bash
cumulus <module> help
```
or
```bash
cumulus help
```

### Dependencies

Cumulus uses [Bundler](http://bundler.io/) to manage dependencies. Run
```bash
gem install bundler
```
followed by
```bash
bundler install
```
to resolve dependencies

### Documentation
See [documentation site](http://lucidsoftware.github.io/cumulus) for details

### Lucid Software
Cumulus was created by [Lucid Software](https://www.golucid.co), creators of [Lucidchart](https://www.lucidchart.com) and [Lucidpress](https://www.lucidpress.com).
