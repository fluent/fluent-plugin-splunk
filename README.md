> [!IMPORTANT]
>
> **This repository is no longer actively maintained and is scheduled to be archived.**
>
> **Recommended Alternative:**
> Community member have created and are actively maintaining an alternative plugin. If you are currently using `fluent-plugin-splunk-enterprise`, we strongly encourage you to migrate to the new community-driven plugin.
>
> For more details, migration instructions, and links to the active repository, please refer to the following discussion:
>
> * [📢 Announcing Two New Modernized Fluentd Plugins: Splunk HEC & Sumo Logic](https://github.com/fluent/fluentd/discussions/5156)
>
> Thank you to everyone who has used and contributed to this project over the years.

# fluent-plugin-splunk-enterprise

## Table of Contents

* [Installation](#installation)
* [out_splunk_hec](#out_splunk_hec)
* [out_splunk_tcp](#out_splunk_tcp)
* [Running test](#running-tests)

## Installation

```
$ fluent-gem install fluent-plugin-splunk-enterprise
```

## [out_splunk_hec](/README.hec.md)

Splunk HTTP Event Collector Output plugin

http://dev.splunk.com/view/event-collector/SP-CAAAE6M

## [out_splunk_tcp](/README.tcp.md)

Splunk TCP inputs Output Plugin

http://docs.splunk.com/Documentation/Splunk/latest/Data/Monitornetworkports

## Running tests

Available Splunk versions in tests are `6.5.2`, `6.4.6`, `6.3.9`, `6,2.12`, `6.1.13` and `6.0.14`.

Start a docker instance Splunk.

```
$ ./docker.sh build <splunk_version>
$ ./docker.sh run <splunk_version>
```

Run tests.

```
$ SPLUNK_VERSION=<splunk_version> bundle exec rake test
```
