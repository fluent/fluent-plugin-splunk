# Fluent::Plugin::Splunk

**This plugin is only for Fluentd Enterprise.**

## Table of Contents

* [out_splunk_hec](#out_splunk_hec)
* [out_splunk_tcp](#out_splunk_tcp)
* [Running test](#running-tests)

## [out_splunk_hec](/README.hec.md)

Splunk HTTP Event Collector Output plugin
http://dev.splunk.com/view/event-collector/SP-CAAAE6M

### [out_splunk_tcp](/README.tcp.md)

Spplunk TCP inputs Output Plugin
http://docs.splunk.com/Documentation/Splunk/latest/Data/Monitornetworkports

## Running tests

Available Splunk versions in test are `6.5.2`, `6.4.6`, `6.3.9`, `6,2.12`, `6.1.13` and `6.0.14`.

Start a docker instance Splunk.

```
$ ./docker.sh login
$ ./docker.sh debug_run <splunk_version>
```

Run tests.

```
$ SPLUNK_VERSION=<splunk_version> bundle exec rake test
```
