vcl 4.0;

backend default {
    .host = "{{ varnish_default_backend_host }}";
    .port = "{{ varnish_default_backend_port }}";
}
