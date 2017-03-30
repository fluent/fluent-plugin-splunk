# Fluent::Plugin::Splunk

This plugin is only for Fluentd Enterprise.

## Usage

### splunk_hec

HTTP Event Collector

```
<match my.logs>
  @type splunk_hec
  host 127.0.0.1
  port 8088
  token 00000000-0000-0000-0000-000000000000
</match>
```

### splunk_tcp

TCP input

```
<match my.logs>
  @type splunk_tcp
  host 127.0.0.1
  port 8089
  event_key
</match>
```

## Configuration

### Common

#### host

```
host 127.0.0.1
```

#### port

```
port 8088
```

#### ssl_verify_peer, ca_file, client_cert, client_key, client_key_pass

```
ssl_verify_peer true # enable ssl
ca_file /path/to/client-key
client_cert /path/to/client_cert
client_key /path/to/client-key
client_key_pass password
```

#### default_host

If you set this, the value is set as host metadata.

```
default_host your-host
```

#### host_key

If you set this, the value associated with this key in each records is used as host metadata. When the key is missing, `default_host` is used.

```
host_key host
```

#### default_source

If you set this, the value is set as source metadata.

```
default_source your-source
```

#### source_key

If you set this, the value associated with this key in each records is used as source metadata. When the key is missing, `default_source` is used.

```
source_key source
```

#### default_index

If you set this, the value is set as index metadata.

```
default_index your-index
```

#### index_key

If you set this, the value associated with this key in each records is used as index metadata. When the key is missing, `default_index` is used.

```
index_key index
```

#### sourcetype

If you set this, the value is set as sourcetype metadata.

```
sourcetype my-sourcetype
```

#### use_ack

This enables [Indexer acknowledgement](https://www.google.co.jp/search?q=splunk+http+ack&oq=splunk+http+ack&aqs=chrome..69i57j69i60l2.2725j0j9&sourceid=chrome&ie=UTF-8). When this is set `true`, `channel` option must also be set.

```
use_ack true
```

#### channel

This is used as [channel identifier](http://dev.splunk.com/view/event-collector/SP-CAAAE8X#aboutchannels). When you set `use_ack` or `raw`, this option must be set.

```
channel 00000000-0000-0000-0000-000000000000
```

#### ack_retry

Indicates how many times the plugin check Indexer acknowledgement.

```
ack_retry 3
```

#### ack_interval

Indicates how many seconds the plugin should wait between checks for Indexer acknowledgement.

```
ack_interval 1
```

#### raw

Enables [raw mode](http://dev.splunk.com/view/event-collector/SP-CAAAE8Y#raw).

* On raw mode, the plugin can't configure metadata at event level. So `*_key` options are ignored. When this is set `true`, channel option must also be set.

```
raw true
```

#### event_key

Specify the key for raw event message. Otherwise record itself is sent as an event. When `raw` is set to `true`, this option is required.

```
event_key event
```

#### line_breaker

The line breaker used when multiple records is sent at once.

### splunk_tcp

#### format

Available formats: `raw`, `json` and `kv`.

```
format raw
```

#### event_key

For `raw` format.
Specify the key raw event message. For example, if the record is `{'event': "your event"}` and `event_key` is `event`, `"your event"` is sent to Splunk.

```
event_key event
```

#### use_fluentd_time

For `json` and `kv` format. Specify whether fluentd's timestamp is injected to the record or not. If the record already has its own time value, this options should be `false`.

```
use_fluentd_time false
```

#### time_key

For `json` and `kv` format, and the case `use_fluentd_time` = `true`. The key name for injected fluentd's timestamp.

#### time_format

For `json` and `kv` format, and the case `use_fluentd_time` = `true`. The format for injected fluentd's timestamp. `unixtime` is a special value for unix timestamp(integer).

```
time_format %Y-%m-%dT%H:%M:%S%z
```

#### localtime

For `json` and `kv` format, and the case `use_fluentd_time` = `true`. Specify whether timestamp is formatted as localtime except the case of `unixtime`.


#### line_breaker

The line breaker used when multiple records is sent at once.

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
