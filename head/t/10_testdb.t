use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Mojo::mysql;

plan skip_all => 'Set TEST_DB="conn_string" variable to enable online test' unless $ENV{TEST_DB};

diag $ENV{TEST_DB};

my $t = Test::Mojo->new('Head', {
  inet_db_conn => $ENV{TEST_DB},

  agent_types => ['gwsyn'],
  smtp_host => 'test',
  mail_from => 'r2d2@test',
});

diag 'Database tables will be created on first access';


my $db = $t->app->mysql_inet->db;

ok($db->ping, 'Pinging test database');

my $tables = $db->tables;

#diag explain $tables;
ok(eq_set($tables, [
'adaily',
'amonthly',
'audit_log',
'op_log',
'clients',
'devices',
'profiles',
'profiles_agents',
'sync_flags',
'mojo_migrations',
]), 'Tables are created');


done_testing();
