# Fluent::Plugin::Splunk

This plugin is only for Fluentd Enterprise.

## Usage

### splunk_hec

HTTP Event Collector

```
<match my.logs>
  @type splunk_hec
</match>
```

### splunk_tcp

TCP input

```
<match my.logs>
  @type splunk_tcp
</match>
```

## Configuration

### splunk_hec

### splunk_tcp

## Running tests

Available Splunk versions in test are `6.5.2`, `6.4.6`, `6.3.9`, `6,2.12`, `6.1.13` and 6.0.14.

Start a docker instance Splunk.

```
$ ./docker.sh login
$ ./docker.sh debug_run <splunk_version>
```

Run tests.

```
$ SPLUNK_VERSION=<splunk_version> bundle exec rake test
```
