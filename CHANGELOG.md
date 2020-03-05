# Release v0.10.2 - 2020/03/04

* out_splunk_hec: Add `auto_generate_channel` parameter

# Release v0.10.1 - 2020/03/03

* output: Support v1 multi-workers

# Release v0.10.0 - 2019/06/13

* out_splunk_hec: Send time with nano seconds if possible when `use_fluentd_time` is set to true

# Release v0.9.3 - 2019/06/06

* out_splunk_hec: Improve sourcetype usage by adding `default_sourcetype`, `sourcetype_key` and `remove_sourcetype_key`

# Release v0.9.2 - 2019/03/14

## Enhancements

* out_splunk_hec: Add `remove_host_key`, `remove_source_key` and `remove_index_key`

# Release v0.9.1 - 2018/08/14

## New Features

* Use `yajl` instead of `json` to avoid encoding error

# Release v0.9.0 - 2018/05/03

## New Features

* Open sourced from fluentd enterprise: `out_splunk_tcp` and `out_splunk_hec`
