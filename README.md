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
