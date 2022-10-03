## 3.1.2
  - Fix: eliminate high CPU usage when data timeout is disabled and no data is available on the socket [#30](https://github.com/logstash-plugins/logstash-input-unix/pull/30)

## 3.1.1
  - Fix: unable to stop plugin (on LS 6.x) [#29](https://github.com/logstash-plugins/logstash-input-unix/pull/29)
  - Refactor: plugin internals got reviewed for `data_timeout => ...` to work reliably

## 3.1.0
  - Feat: adjust fields for ECS compatibility [#28](https://github.com/logstash-plugins/logstash-input-unix/pull/28) 

## 3.0.7
  - Docs: Set the default_codec doc attribute.

## 3.0.6
  - Update gemspec summary

## 3.0.5
  - Fix some documentation issues

## 3.0.3
  - Preserve values provided in `add_field` for `host` and `path`.

## 3.0.2
  - Relax constraint on logstash-core-plugin-api to >= 1.60 <= 2.99

## 3.0.1
  - Republish all the gems under jruby.
## 3.0.0
  - Update the plugin to the version 2.0 of the plugin api, this change is required for Logstash 5.0 compatibility. See https://github.com/elastic/logstash/issues/5141
# 2.0.6
  - Depend on logstash-core-plugin-api instead of logstash-core, removing the need to mass update plugins on major releases of logstash
# 2.0.5
  - New dependency requirements for logstash-core for the 5.0 release
## 2.0.2
 - Make plugin and spec work when Thread.abort_on_exception is true

## 2.0.0
 - Plugins were updated to follow the new shutdown semantic, this mainly allows Logstash to instruct input plugins to terminate gracefully, 
   instead of using Thread.raise on the plugins' threads. Ref: https://github.com/elastic/logstash/pull/3895
 - Dependency on logstash-core update to 2.0

