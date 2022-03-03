package Head::Plugin::Json_schemas;
use Mojo::Base 'Mojolicious::Plugin';
use JSON::Validator;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # $self->json_validate($json, 'schema_name')
  # renders error 503 on validation errors
  $app->helper(json_validate => sub {
    my ($self, $json, $schema) = @_;
    my $jv = JSON::Validator->new;
    $jv->schema("data:///$schema"); # die on schema errors!
    $jv->schema->coerce('numbers');
    if (my @errors = $jv->validate($json)) {
      $self->render(text => "Format @errors", status => 503);
      return undef;
    }
    return 1;
  });
}


1;
__DATA__

@@ server_record
{
  "type": "object",
  "required": ["cn", "ip", "mac", "no_dhcp", "rt", "defjump", "speed_in", "speed_out", "qs", "limit_in", "profile"],
  "properties": {
    "id": { "type":"integer" },
    "cn": { "type":"string", "minLength":1 },
    "desc": { "type":"string" },
    "create_time": { "type":"string" },
    "email": {
      "type":"string",
      "description":"Email regexp",
      "pattern":"^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$"
    },
    "email_notify": { "type":"integer", "enum":[0,1] },
    "ip": {
      "type":"string",
      "description":"Regexp::Common ^$RE{net}{IPv4}$",
      "pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))$"
    },
    "mac": {
      "type":"string",
      "description":"Regexp::Common ^$RE{net}{MAC}$",
      "pattern":"^(?:(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}))$"
    },
    "no_dhcp": { "type":"integer", "enum":[0,1] },
    "rt": { "type":"integer", "minimum":0, "maximum":9 },
    "defjump": { "type":"string", "enum":["ACCEPT","DROP","HTTP_ICMP","HTTP_IM_ICMP","ICMP_ONLY"] },
    "speed_in": { "type":"string", "minLength":1 },
    "speed_out": { "type":"string", "minLength":1 },
    "qs": { "type":"integer", "minimum":0, "maximum":9 },
    "limit_in": { "type":"integer", "minimum":0 },
    "sum_limit_in": { "type":"integer", "minimum":0 },
    "blocked": { "type":"integer", "enum":[0,1] },
    "flagged": { "type":"integer", "enum":[0,1] },
    "profile": { "type":"string", "minLength":1 },
    "profile_name": { "type":"string", "minLength":1 }
  }
}

@@ client_record
{
  "type": "object",
  "required": ["cn", "guid", "login"],
  "properties": {
    "id": { "type":"integer" },
    "cn": { "type":"string", "minLength":1 },
    "desc": { "type":"string" },
    "create_time": { "type":"string" },
    "guid": {
      "type":"string",
      "description":"Guid regexp or empty",
      "pattern":"^$|^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$"
    },
    "login": { "type":"string", "minLength":1 },
    "email": {
      "type":"string",
      "description":"Email regexp",
      "pattern":"^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$"
    },
    "email_notify": { "type":"integer", "enum":[0,1] }
  }
}

@@ client_device_record
{
  "type": "object",
  "required": ["name", "ip", "mac", "no_dhcp", "rt", "defjump", "speed_in", "speed_out", "qs", "limit_in", "profile"],
  "properties": {
    "id": { "type":"integer" },
    "name": { "type":"string", "minLength":1 },
    "desc": { "type":"string" },
    "create_time": { "type":"string" },
    "email": {
      "type":"string",
      "description":"Email regexp",
      "pattern":"^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$"
    },
    "ip": {
      "type":"string",
      "description":"Regexp::Common ^$RE{net}{IPv4}$",
      "pattern":"^(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))$"
    },
    "mac": {
      "type":"string",
      "description":"Regexp::Common ^$RE{net}{MAC}$",
      "pattern":"^(?:(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}):(?:[0-9a-fA-F]{1,2}))$"
    },
    "no_dhcp": { "type":"integer", "enum":[0,1] },
    "rt": { "type":"integer", "minimum":0, "maximum":9 },
    "defjump": { "type":"string", "enum":["ACCEPT","DROP","HTTP_ICMP","HTTP_IM_ICMP","ICMP_ONLY"] },
    "speed_in": { "type":"string", "minLength":1 },
    "speed_out": { "type":"string", "minLength":1 },
    "qs": { "type":"integer", "minimum":0, "maximum":9 },
    "limit_in": { "type":"integer", "minimum":0 },
    "sum_limit_in": { "type":"integer", "minimum":0 },
    "blocked": { "type":"integer", "enum":[0,1] },
    "flagged": { "type":"integer", "enum":[0,1] },
    "profile": { "type":"string", "minLength":1 },
    "profile_name": { "type":"string", "minLength":1 },
    "client_id": { "type":"integer" },
    "client_type": { "type":"integer", "enum":[0,1] },
    "client_cn": { "type":"string", "minLength":1 },
    "client_login": { "type":"string", "minLength":1 }
  }
}

@@ limit_record
{
  "type": "object",
  "required": ["qs", "limit_in", "add_sum", "reset_sum"],
  "properties": {
    "qs": { "type":"integer", "minimum":0, "maximum":9 },
    "limit_in": { "type":"integer", "minimum":0 },
    "add_sum": { "type":"integer", "enum":[0,1] },
    "reset_sum": { "type":"integer", "enum":[0,1] }
  }
}

@@ profile_record
{
  "type": "object",
  "required": ["profile", "name"],
  "properties": {
    "id": { "type":"integer" },
    "profile": {
      "type":"string",
      "description":"Latin characters, numbers, and ._-",
      "pattern":"^[A-Za-z_][A-Za-z0-9_\\.\\-]*$"
    },
    "name": { "type":"string", "minLength":1 }
  }
}

@@ profile_agent_record
{
  "type": "object",
  "required": ["name", "type", "url", "block"],
  "properties": {
    "id": { "type":"integer" },
    "name": { "type":"string", "minLength":1 },
    "type": {
      "type":"string",
      "description":"type or type@hostname",
      "pattern":"^([^@]+)(?:@([^@]+))?$"
    },
    "url": { "type":"string", "minLength":1 },
    "block": { "type":"integer", "enum":[0,1] },
    "profile": { "type":"string", "minLength":1 },
    "profile_name": { "type":"string", "minLength":1 },
    "flagged": { "type":"integer", "enum":[0,1] }
  }
}

