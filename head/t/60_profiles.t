use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;

use Mojo::mysql;
use Head::Ural::Profiles;

plan skip_all => 'Set TEST_DB="conn_string" variable to enable online test' unless $ENV{TEST_DB};

#diag $ENV{TEST_DB};
my $t = Test::Mojo->new('Head', {
  inet_db_conn => $ENV{TEST_DB},

  agent_types => ['gwsyn'],
  smtp_host => 'test',
  mail_from => 'r2d2@test',
});


dies_ok( sub { Head::Ural::Profiles->new() }, 'Empty constructor');


my $p = Head::Ural::Profiles->new($t->app);
isa_ok($p, 'Head::Ural::Profiles');

# create gwtest1 profile
my $db = $t->app->mysql_inet->db;
$db->query("DELETE FROM profiles");
$db->query("INSERT INTO profiles (profile, name) VALUES ('gwtest1', 'test')");

is($p->exist('gwtest1'), 1, 'gwtest1 profile exists');
is($p->exist('asdfg'), 0, 'asdfg profile does not exist');

my $r = $p->eachagent(sub {
  my ($profile_key, $agent_key, $agent) = @_;
  diag "$agent_key => $agent->{name}";
});
is($r, 1, "eachagent1 returned 1");

$r = $p->eachagent('test2', sub {
  my ($profile_key, $agent_key, $agent) = @_;
  diag "$agent_key => $agent->{name}";
});
is($r, 1, "eachagent2 returned 1");

$r = $p->eachagent('gwtest1', sub {
  my ($profile_key, $agent_key, $agent) = @_;
  diag "$agent_key => $agent->{name}";
});
is($r, 1, "eachagent3 returned 1");


done_testing();
