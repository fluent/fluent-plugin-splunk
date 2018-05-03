# out_splunk_tcp - Splunk TCP inputs Output Plugin

## Table of Contents

* [Example Configuration](#example-configuration)
   * [not formatted by the plugin](#not-formatted-by-the-plugin)
   * [formatted by the plugin](#formatted-by-the-plugin)
* [Parameters](#parameters)
   * [type (required)](#type-required)
   * [host (required)](#host-required)
   * [port (required)](#port-required)
   * [format](#format)
   * [event_key](#event_key)
   * [use_fluentd_time](#use_fluentd_time)
   * [time_key](#time_key)
   * [time_format](#time_format)
   * [localtime](#localtime)
   * [line_breaker](#line_breaker)
   * [use_ssl](#use_ssl)
   * [ssl_verify](#ssl_verify)
   * [ca_file](#ca_file)
   * [client_cert](#client_cert)
   * [client_key](#client_key)
   * [client_key_pass](#client_key_pass)

## Example Configuration

### not formatted by the plugin

* fluentd record: `1490924392 {"log": "GET / HTTP/1.1 200"}`
* sent as: `GET / HTTP/1.1 200`


```
<match splunk.**>
  @type splunk_tcp
  host example.com
  port 8089

  # format parameter
  format raw
  event_key log

  # ssl parameter
  use_ssl true
  ca_file /path/to/ca.pem

  # buffered output parameter
  flush_interval 10s
</match>
```

### formatted by the plugin

This example shows json format.

* fluentd record: `1490924392 {"method": "GET", path: "/", code: 200}`
* sent as: `{"time": 1490924392, "method": "GET", path: "/", code: 200}`

```
<match splunk.**>
  @type splunk_tcp
  host example.com
  port 8089

  format json

  # ssl parameter
  use_ssl true
  ca_file /path/to/ca.pem

  # flush
  flush_interval 10s
</match>
```

You can use a sourcetype configuration like the following.

```
[fluentd]
TIME_PREFIX=\"time\":
TIME_FORMAT=%s
KV_MODE=json
```

## Parameters

### type (required)

The value must be `splunk_tcp`.

### host (required)

The Splunk hostname.

### port (required)

The Splunk port.

### format

#### `raw` (the default)

The value specified by `event_key` parameter is sent to Splunk as an event.
If the key missing in a record, nothing is sent. 

##### Related parameters
* event_key 

#### `json`

`KV_MODE=json` can be used as sourcetype configuration.

##### Related parameters
* use_fluentd_time
* time_key
* time_format
* localtime

#### `kv`

Key-value pairs like the following.

```
time=1490862563 method="GET" path="/" code=200
```

`KV_MODE=auto` can be used as sourcetype configuration.

##### Related parameters
* use_fluentd_time
* time_key
* time_format
* localtime

### event_key

For `raw` format.

This parameter is required when the format is `raw`.

### use_fluentd_time

For `json` and `kv` format.
The default: `true`

If set to `true`, fluentd's timestamp is injected to the top of the record before sent to Splunk.

For example, the first record is converted to the next one.

```
{"method": "GET", path: "/", code: 200}
```

```
{"time": 1490862563, "method": "GET", path: "/", code: 200}
```

If your record already has the column for a timestamp, this parameter should be `false`.

### time_key

For `json` and `kv` format.
The default: `time`

The key which is inserted into a record by `use_fluend_time` parameter.

### time_format

For `json` and `kv` format.
The default: `unixtime`

The format of timestamp which is inserted by `use_fluentd_time` parameter.
You can specify a strftime format or `unixtime` (unix timestamp as integer).

For example, 

```
time_format %Y-%m-%dT%H:%M:%S%z
```

the first record record is converted to the next one by this `time_format`.

```
{"method": "GET", path: "/", code: 200}
```

```
{"time": "2017-03-30T08:29:23+0000", "method": "GET", path: "/", code: 200}
```

### localtime

For `json` and `kv` format
The default: `false`

If `true`, use local time when the timestamp formatted as the strftime format. Otherwise UTC is used.

### line_breaker

The default: `"\n"`

The line breaker used when multiple records are sent at once.

### use_ssl

The default: `false`

Use SSL when connecting to Splunk.

### ssl_verify

The default: `true`

Enable/Disable SSL certificate verification.

### ca_file

The path of CA file.

### client_cert

The path of client certificate file.

### client_key

The path of client key file

### client_key_pass

The passphrase of client key.
