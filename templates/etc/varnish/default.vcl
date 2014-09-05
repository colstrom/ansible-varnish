vcl 4.0;

import directors;
import std;

###
# Varnish Documentation
#   https://www.varnish-cache.org/docs/trunk/users-guide/vcl-built-in-subs.html
#   https://www.varnish-cache.org/docs/trunk/reference/vcl.html
##

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

###
# vcl_init
#   Called when VCL is loaded, before any requests pass through it. Typically used to initialize VMODs.
###
# The vcl_init subroutine may terminate with calling return() with one of the following keywords:
#
# ok
#   Normal return, VCL continues loading.
##

sub vcl_init {
  new application = directors.round_robin();
{% for backend in varnish_backend_hosts %}
  application.add_backend(application_{{ loop.index }});
{% endfor %}
}

###
# vcl_recv
#   Called at the beginning of a request, after the complete request has been received and parsed.
#   Its purpose is to decide whether or not to serve the request, how to do it, and, if applicable, which backend to use. 
#   It is also used to modify the request
###
# The vcl_recv subroutine may terminate with calling return() on one of the following keywords:
#
# synth(status code, reason)
#   Return a synthetic object with the specified status code to the client and abandon the request.
# pass
#   Switch to pass mode. Control will eventually pass to vcl_pass.
# pipe
#   Switch to pipe mode. Control will eventually pass to vcl_pipe.
# hash
#   Continue processing the object as a potential candidate for caching. Passes the control over to vcl_hash.
# purge
#   Purge the object and it's variants. Control passes through vcl_hash to vcl_purge.
#

sub vcl_recv {
  set req.backend_hint = application.backend();

  ###
  # Avoid processing uncacheable requests
  ###

  if (req.http.Authorization) {
    set req.http.X-Passthrough-Reason = "No Caching Authenticated Content";
    return (pass);
  }

{% if varnish_uri_blacklist_enabled %}
  if ((req.url ~ "{{ varnish_uri_blacklist_regexp }}")) {
    set req.http.X-Passthrough-Reason = "Path in Blacklist";
    return(pass);
  }
{% endif %}

{% if varnish_diagnostic_headers_forwarded_for %}
  ###
  # Inject X-Forwarded-For headers, but only once.
  ###

  if (req.restarts == 0) {
    if (req.http.X-Forwarded-For) {
      set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
    } else {
      set req.http.X-Forwarded-For = client.ip;
    }
  }
{% endif %}

{% if varnish_header_sanitization_enabled %}
  ###
  # Header Sanitization
  ###

{% if varnish_header_sanitization_discard_host_port %}
  set req.http.Host = regsub(req.http.Host, ":[0-9]+", "");
{% endif %}

{% if varnish_header_sanitization_normalize_accept_encoding %}
  if (req.http.Accept-Encoding) {
    if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
      unset req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      unset req.http.Accept-Encoding;
    }
  }
{% endif %}

{% endif %}

{% if varnish_cookie_sanitization_enabled %}
  ###
  # Cookie Sanitization
  ###
  if (req.http.Cookie) {
    set req.http.X-Cookie-Unmodified = req.http.Cookie;

  {% for cookie in varnish_cookie_sanitization_blacklist %}
    set req.http.Cookie = regsuball(req.http.Cookie, "{{ cookie }}=[^;]+(; )?", "");
  {% endfor %}

    ### General Cleanup
    set req.http.Cookie = regsuball(req.http.Cookie, "^;\s*", "");
    if (req.http.Cookie ~ "^\s*$") {
        unset req.http.Cookie;
    }
    if (req.http.Cookie) {
      set req.http.X-Cookie-Sanitized = req.http.Cookie;
    }
  }
{% endif %}

{% if varnish_uri_sanitization_enabled %}
  ###
  # URI Sanitization
  ###
  
  if (req.url ~ "(\?|&){{ varnish_uri_sanitization_regexp }}=") {
    set req.url = regsuball(req.url, "&{{ varnish_uri_sanitization_regexp }}=([A-z0-9_\-\.%25]+)", "");
    set req.url = regsuball(req.url, "\?{{ varnish_uri_sanitization_regexp }}=([A-z0-9_\-\.%25]+)", "?");
    set req.url = regsub(req.url, "\?&", "?");
    set req.url = regsub(req.url, "\?$", "");
  }
  if (req.url ~ "\#") {
    set req.url = regsub(req.url, "\#.*$", "");
  }
{% endif %}

{% if varnish_workaround_telusdotcom_browser_profile %}
  ###
  # Workaround and Diagnostics for BrowserProfile and Language/Region Detection on TELUS.com
  ###

  if (req.http.Cookie ~ "BrowserProfile") {
    set req.http.X-BrowserProfile = regsuball(req.http.Cookie, "(.*)BrowserProfile=([^;]*)(.*)", "\2");
    if (req.http.X-BrowserProfile ~ "language") {
      set req.http.X-Language = std.tolower(regsuball(req.http.X-BrowserProfile, "(.*)language\\.:\\.([^\\]*)(.*)", "\2"));
      set req.http.X-Language-Found = "YES:BrowserProfile";
    }
    if (req.http.X-BrowserProfile ~ "region") {
      set req.http.X-Region = std.tolower(regsuball(regsuball(req.http.X-BrowserProfile, "geo\\.\:{(.*)\}", ""), "(.*)region\\.:\\.([^\\]*)(.*)", "\2"));
      set req.http.X-Region-Found = "YES:BrowserProfile";
    }
    if (req.http.X-BrowserProfile ~ "geo") {
      set req.http.X-BrowserProfile-Geolocation = regsuball(req.http.X-BrowserProfile, "(.*)geo..:\\.([^\\]*)(.*)", "\2");
      set req.http.X-BrowserProfile-Geolocation-Found = "YES";

      if (req.http.X-BrowserProfile-Geolocation ~ "country") {
        set req.http.X-BrowserProfile-Geolocation-Country = regsuball(req.http.X-BrowserProfile-Geolocation, "(.*)country\\.:\\.([^\\]*)(.*)", "\2");
      }
      if (req.http.X-BrowserProfile-Geolocation ~ "region") {
        set req.http.X-BrowserProfile-Geolocation-Region = regsuball(req.http.X-BrowserProfile-Geolocation, "(.*)region\\.:\\.([^\\]*)(.*)", "\2");
      }
      if (req.http.X-BrowserProfile-Geolocation ~ "city") {
        set req.http.X-BrowserProfile-Geolocation-City = regsuball(req.http.X-BrowserProfile-Geolocation, "(.*)city\\.:\\.([^\\]*)(.*)", "\2");
      }
      if (req.http.X-BrowserProfile-Geolocation ~ "isp") {
        set req.http.X-BrowserProfile-Geolocation-ISP = regsuball(req.http.X-BrowserProfile-Geolocation, "(.*)isp\\.:\\.([^\\]*)(.*)", "\2");
      }
    } else {
      set req.http.X-BrowserProfile-Geolocation-Found = "NO";
    }
  }

  if (!req.http.X-Language) {
    if (req.http.Cookie ~ "lang=") {
      set req.http.X-Language = std.tolower(regsuball(req.http.Cookie, "(.*)lang=([^;]*)(.*)", "\2"));
      set req.http.X-Language-Found = "YES:lang";
    } else {
      set req.http.X-Language = "en";
      set req.http.X-Language-Found = "NO";
    }
  }

  if (!req.http.X-Region) {
    if (req.http.Cookie ~ "prov=") {
      set req.http.X-Region = std.tolower(regsuball(req.http.Cookie, "(.*)prov=([^;]*)(.*)", "\2"));
      set req.http.X-Region-Found = "YES:prov";
    } else {
      set req.http.X-Region = "bc";
      set req.http.X-Region-Found = "NO";
    }
  }

  if (req.url ~ "/(en|fr)/") {
    if (req.url ~ "/en/" && req.http.X-Language != "en") {
      set req.http.X-Passthrough-Reason = "Unaligned Language (Path: /en/) vs (Cookie: " + req.http.X-Language + ")";
      return(pass);
    }
    if (req.url ~ "/fr/" && req.http.X-Language != "fr") {
      set req.http.X-Passthrough-Reason = "Unaligned Language (Path: /fr/) vs (Cookie: " + req.http.X-Language + ")";
      return(pass);
    }
  } else {
      set req.http.X-Passthrough-Reason = "Not Set in Path (Language)";
    return(pass);
  }

  if (req.url ~ "/(ab|bc|mb|nb|nl|ns|nt|nu|on|pe|qc|sk|yt)/") {
    {% for province in ['ab', 'bc', 'mb', 'nb', 'nl', 'ns', 'nt', 'nu', 'on', 'pe', 'qc', 'sk', 'yt'] %}
    if (req.url ~ "/{{ province }}/" && req.http.X-Region != "{{ province }}") {
      set req.http.X-Passthrough-Reason = "Unaligned Region (Path: /{{ province }}/) vs (Cookie: " + req.http.X-Region + ")";
      return(pass);
    }
    {% endfor %}
  } else {
      set req.http.X-Passthrough-Reason = "Not Set in Path (Province)";
    return(pass);
  }
{% endif %}

{% if varnish_cookie_sanitization_discard_from_client %}
    unset req.http.Cookie;
{% endif %}
}

###
# vcl_hit
#   Called when a cache lookup is successful.
###
# The vcl_hit subroutine may terminate with calling return() with one of the following keywords:
#
# restart
#   Restart the transaction. Increases the restart counter. If the number of restarts is higher than max_restarts Varnish emits a guru meditation error.
# deliver
#   Deliver the object. Control passes to vcl_deliver.
# synth(status code, reason)
#   Return the specified status code to the client and abandon the request.
###

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

###
# vcl_backend_response
#   Called after the response headers has been successfully retrieved from the backend.
###
# The vcl_backend_response subroutine may terminate with calling return() with one of the following keywords:
#
# deliver
#   Possibly insert the object into the cache, then deliver it to the Control will eventually pass to vcl_deliver.
# abandon
#   Abandon the backend request and generates an error.
# retry
#   Retry the backend transaction. Increases the retries counter. If the number of retries is higher than max_retries Varnish emits a guru meditation error.
###

sub vcl_backend_response {
{% if varnish_workaround_telusdotcom_browser_profile %}
  if (bereq.http.X-Language) {
    set beresp.http.X-Language = bereq.http.X-Language;
#    if (bereq.http.X-Language-Found) {
#      set beresp.http.X-Language-Found = bereq.http.X-Language-Found;
#    }
  }
  if (bereq.http.X-Region) {
    set beresp.http.X-Region = bereq.http.X-Region;
#    if (bereq.http.X-Region-Found) {
#      set beresp.http.X-Region-Found = bereq.http.X-Region-Found;
#    }
  }
{% endif %}

{% if varnish_uri_blacklist_enabled %}
  if (bereq.url ~ "{{ varnish_uri_blacklist_regexp }}") {
    set beresp.http.X-Cacheable = "NO:Path in Blacklist";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } else {
    if (bereq.http.X-Passthrough-Reason) {
{% if varnish_diagnostic_headers_passthrough_reason %}
      set beresp.http.X-Passthrough-Reason = bereq.http.X-Passthrough-Reason;
{% endif %}
      return(deliver);
    } else {
{% if varnish_cookie_sanitization_discard_from_server %}
      unset beresp.http.Set-Cookie;
{% endif %}
    }
  }
{% else %}
{% if varnish_cookie_sanitization_discard_from_server %}
  unset beresp.http.Set-Cookie;
{% endif %}
{% endif %}

{% if varnish_diagnostic_headers_enabled %}
  if (bereq.http.Cookie) {
    set beresp.http.X-Cacheable = "NO:Cookie in Request";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } elsif (beresp.http.Set-Cookie) {
    set beresp.http.X-Cacheable = "NO:Set-Cookie in Response";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } elsif (beresp.http.Cache-Control ~ "private") {
    set beresp.http.X-Cacheable = "NO:Cache-Control=private";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } elsif (beresp.http.X-No-Cache) {
    set beresp.http.X-Cacheable = "NO:X-No-Cache";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } elsif (beresp.ttl <= 0s) {
    set beresp.http.X-Cacheable = "NO:Not Cacheable";
    set beresp.uncacheable = true;
    set beresp.ttl = {{ varnish_backend_response_ttl }}s;
    return(deliver);
  } else {
    set beresp.http.X-Cacheable = "YES";
  }
{% endif %}

  set beresp.grace = {{ varnish_grace_period }};
}

###
# vcl_deliver
#   Called before a cached object is delivered to the client.
###
# The vcl_deliver subroutine may terminate with calling return() with one of the following keywords:
#
# deliver
#   Deliver the object to the client.
# restart
#   Restart the transaction. Increases the restart counter. If the number of restarts is higher than max_restarts Varnish emits a guru meditation error.
###

sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
