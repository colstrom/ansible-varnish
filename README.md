# ansible-varnish

[Varnish Cache](https://www.varnish-cache.org/), the high-performance HTTP accelerator.

[![Platforms](http://img.shields.io/badge/platforms-ubuntu-lightgrey.svg?style=flat)](#)

Tunables
--------
* `varnish_user`: varnish
* `varnish_group`: varnish
* `varnish_runtime_root` (string) - Directory for runtime data
* `varnish_pidfile_path` (string) - Path for pidfile
* `varnish_default_backend_host` (string) - Default address for backend
* `varnish_default_backend_port` (integer) - Default port for backend
* `varnish_default_backend_ttl` (integer) - Default cache validity for backends
* `varnish_accepts_external_connections` (boolean) - Bind to 0.0.0.0
* `varnish_listen_port` (integer) - Port to listen on
* `varnish_admin_address` (string) - Address for admin interface
* `varnish_admin_port` (string) - Port for admin interface
* `varnish_using_vcl` (boolean) - Use included VCL?
* `varnish_vcl_path` (string) - Path to VCL file
* `varnish_secret_path` (string) - Path to secret file
* `varnish_storage_type` (string) - Storage method to use?
* `varnish_storage_path` (string) - Path to storage file
* `varnish_storage_size` (string) - Size of storage
* `varnish_backend_hosts` (list) - Backend hosts
* `varnish_backend_port` (integer) - Port for backend hosts
* `varnish_backend_response_ttl` (string) - Cache duration for backend responses
* `varnish_health_checks_enabled` (boolean) - Enable health checks?
* `varnish_health_check_url` (string) - Context path to use for health checks?
* `varnish_health_check_interval` (string) - How often to check backend health?
* `varnish_health_check_timeout` (string) - Assume a backend is dead if it responds slower than this
* `varnish_health_check_window` (integer) - How many health checks to consider
* `varnish_health_check_threshold` (integer) - At least this many checks must pass.
* `varnish_grace_period` (string) - How long can an object be served from cache if no backend is available?
* `varnish_performance_tuning_enabled` (boolean) - Aggressive performance tuning. Assumes server is dedicated to varnish.
* `varnish_thread_pools` (integer) - Number of thread pools
* `varnish_thread_pool_add_delay` (string) - Artificial delay before spawning threads.
* `varnish_thread_pool_min` (integer) - Minimum threads per pool
* `varnish_thread_pool_max` (integer) - Maximum threads per pool
* `varnish_cli_timeout` (string) - Timeout for responses from CLI requests
* `varnish_lru_interval` (string) - Interval for updating the LRU list
* `varnish_timeout_linger` (string) - Keep threads around for this long after they time out
* `varnish_connect_timeout` (string) - Time to wait for a backend connection
* `varnish_diagnostic_headers_enabled` (boolean) - Enable diagnostic headers?
* `varnish_diagnostic_headers_forwarded_for` (boolean) - Enabled `X-Forwarded-For` headers?
* `varnish_diagnostic_headers_cache` (boolean) - Enable `X-Cache-Hit` headers?
* `varnish_diagnostic_headers_cacheable` (boolean) - Enable `X-Cacheable` headers?
* `varnish_diagnostic_headers_passthrough_reason` (boolean) - Enable `X-Passthrough-Reason` headers?
* `varnish_request_sanitization_enabled` (boolean) - Enable request sanitization?
* `varnish_header_sanitization_enabled` (string) - Enable header sanitization?
* `varnish_header_sanitization_discard_host_port` (boolean) - Discard host port from requests?
* `varnish_header_sanitization_normalize_accept_encoding` (boolean) - Normalize `Accept-Encoding` headers to improve cache hit rates?
* `varnish_cookie_sanitization_enabled` (string) - Sanitize cookies to improve cache hit rates?
* `varnish_cookie_sanitization_discard_from_client` (boolean) - Discard cookies from client?
* `varnish_cookie_sanitization_discard_from_server` (boolean) - Discard cookies from server?
* `varnish_cookie_sanitization_blacklist` (list) - Cookies to remove
* `varnish_uri_sanitization_enabled` (string) - Sanitize URIs to improve cache hit rates
* `varnish_uri_sanitization_regexp` (string) - Regexp to match for URI sanitization
* `varnish_uri_blacklist_enabled` (boolean) - Don't cache certain paths
* `varnish_uri_blacklist_regexp` (string) - Regexp for paths not to cache
* `varnish_workaround_telusdotcom_browser_profile` (boolean) - Specific workaround you probably don't need.

Dependencies
------------
* [telusdigital.apt-repository](https://github.com/telusdigital/ansible-apt-repository/)

Example Playbook
----------------
    - hosts: servers
      roles:
         - role: telusdigital.varnish

License
-------
[MIT](https://tldrlegal.com/license/mit-license)

Contributors
------------
* [Chris Olstrom](https://colstrom.github.io/) | [e-mail](mailto:chris@olstrom.com) | [Twitter](https://twitter.com/ChrisOlstrom)
* Aaron Pederson
* Steven Harradine
