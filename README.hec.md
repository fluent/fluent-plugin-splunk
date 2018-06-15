# out_splunk_hec - Splunk HTTP Event Collector Output Plugin

## Table of Contents

* [Example Configuration](#example-configuration)
* [Parameters](#parameters)
   * [type (required)](#type-required)
   * [host (required)](#host-required)
   * [port (required)](#port-required)
   * [token (required)](#token-required)
   * [default_host](#default_host)
   * [host_key](#host_key)
   * [defaout_source](#defaout_source)
   * [source_key](#source_key)
   * [default_index](#default_index)
   * [index_key](#index_key)
   * [sourcetype](#sourcetype)
   * [use_fluentd_time](#use_fluentd_time)
   * [use_ack](#use_ack)
   * [channel](#channel)
   * [ack_interval](#ack_interval)
   * [ack_retry_limit](#ack_retry_limit)
   * [raw](#raw)
   * [event_key](#event_key)
   * [line_breaker](#line_breaker)
   * [use_ssl](#use_ssl)
   * [ssl_verify](#ssl_verify)
   * [ca_file](#ca_file)
   * [client_cert](#client_cert)
   * [client_key](#client_key)
   * [client_key_pass](#client_key_pass)

## Example Configuration

```
<match splunk.**>
  @type splunk_hec
  host example.com
  port 8089
  token 00000000-0000-0000-0000-000000000000

  # metadata parameter
  default_source fluentd

  # ack parameter
  use_ack true
  channel 8e69d7b3-f266-e9f3-2747-cc5b7f809897
  ack_retry 8

  # ssl parameter
  use_ssl true
  ca_file /path/to/ca.pem

  # buffered output parameter
  flush_interval 10s
</match>
```

## Parameters

### type (required)

The value must be `splunk_hec`.

### host (required)

The Splunk hostname.

### port (required)

The Splunk port.

### token (required)

The token for HTTP Event Collector.

### default_host

If you set this, the value is set as host metadata.

### host_key

If you set this, the value associated with this key in each record is used as host metadata. When the key is missing, `default_host` is used.

### defaout_source

If you set this, the value is set as source metadata.

### source_key

If you set this, the value associated with this key in each record is used as source metadata. When the key is missing, `default_source` is used.

### default_index

If you set this, the value is set as index metadata.

### index_key

If you set this, the value associated with this key in each record is used as index metadata. When the key is missing, `default_index` is used.

### sourcetype

If you set this, the value is set as sourcetype metadata.

### use_fluentd_time

The default: `true`

If set true, fluentd's timestamp is used as time metadata. If the record already has its own time value, this options should be `false`.

### use_ack

Enable/Disable [Indexer acknowledgement](https://www.google.co.jp/search?q=splunk+http+ack&oq=splunk+http+ack&aqs=chrome..69i57j69i60l2.2725j0j9&sourceid=chrome&ie=UTF-8). When this is set `true`, `channel` parameter is required.

### channel

This is used as [channel identifier](http://dev.splunk.com/view/event-collector/SP-CAAAE8X#aboutchannels).
 When you set `use_ack` or `raw`, this parameter is required.

### ack_interval

The default: `1`

Specify how many seconds the plugin should wait between checks for Indexer acknowledgement.

### ack_retry_limit

The default: `3`

Specify how many times the plugin check Indexer acknowledgement.

### raw

Enable [raw mode](http://dev.splunk.com/view/event-collector/SP-CAAAE8Y#raw).

On raw mode, the plugin can't configure metadata at event level and time metadata. So `*_key` and `use_fluentd_time` parameters are ignored.
When this is set `true`, `event_key` and `channel` parameter must also be set.

Example:

* configuration: `raw = true, event_key = "log"`
* fluentd record: `1490924392 {"foo": "bar", "log": "GET / HTTP/1.1 200"}`
* sent as: `GET / HTTP/1.1 200`

### event_key

Only for raw mode. The value specified by this key is sent as an event.
When `raw` is set to `true`, this parameter is required.

* fluentd record: `1490924392 {"log": "GET / HTTP/1.1 200"}`
* sent as: `GET / HTTP/1.1 200`

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
