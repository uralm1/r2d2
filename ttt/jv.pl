#!/usr/bin/perl

use Mojo::Base -strict;
use Mojo::JSON qw(decode_json encode_json);
use JSON::Validator;
use Data::Dumper;

my $jv = JSON::Validator->new;

#$jv->schema({
#  type => 'object',
#  required => ['firstName', 'lastName'],
#  properties => {
#    firstName => {type=>'string', minLength=>1},
#    lastName => {type=>'string', pattern=>qr/^[abc]+$/},
#    age => {type=>'integer', minimum=>0, description=>'Age in years'},
#    ee => {type=>'integer', enum=>[0, 1]},
#  }
#});
$jv->schema('data:///ttt.json');

my $j = {firstName => '123', lastName => 'aab', age => 42, ee=>'1', ee1=>123 };
my $bytes = encode_json $j;
my $j1 = decode_json $bytes;

$jv->schema->coerce('numbers');

my @errors = $jv->validate($j1);

die "@errors" if @errors;

my $s = $jv->schema->data;
#my $s = encode_json $jv->schema->data;
say Dumper $s;
#say $s;
__END__

__DATA__

@@ ttt.json
{
  "type": "object",
  "required": ["firstName", "lastName"],
  "properties": {
    "firstName": {"type":"string", "minLength":1},
    "lastName": {"type":"string", "pattern":"^[abc]+$"},
    "age": {"type":"integer", "minimum":0, "description":"Age in years"},
    "ee": {"type":"integer", "enum":[0, 1]}
  }
}

