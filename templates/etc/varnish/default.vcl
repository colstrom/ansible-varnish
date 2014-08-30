vcl 4.0;

import directors;
import std;

{% for backend in varnish_backend_hosts %}
backend application_{{ loop.index }} {
  .host = "{{ backend }}";
  .port = "{{ varnish_backend_port }}";
{% if varnish_health_checks_enabled %}
  .probe = {
    .url = "{{ varnish_health_check_url }}";
    .interval = {{ varnish_health_check_interval }};
    .timeout  = {{ varnish_health_check_timeout }};
    .window = {{ varnish_health_check_window }};
    .threshold = {{ varnish_health_check_threshold }};
  }
{% endif %}
}
{% endfor %}

sub vcl_init {
  new application = directors.round_robin();
{% for backend in varnish_backend_hosts %}
  application.add_backend(application_{{ loop.index }});
{% endfor %}
}

sub vcl_recv {
  set req.backend_hint = application.backend();
}

sub vcl_hit {
  if (obj.ttl > 0s) {
    return (deliver);
  }
{% if varnish_health_checks_enabled %}
  if (!std.healthy(req.backend_hint) && (obj.ttl + obj.grace > 0s)) {
    return (deliver);
  } else {
    return (fetch);
  }
{% else %}
  if (obj.ttl + obj.grace > 0s) {
     return (deliver);
  }

  return (fetch);
{% endif %}
}

{% if varnish_grace_enabled %}
sub vcl_backend_response {
  set beresp.grace = {{ varnish_grace_period }};
}
{% endif %}