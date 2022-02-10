use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;

use Head::Ural::Profiles;

plan skip_all => 'Set TEST_DB=1 variable to enable online test' unless $ENV{TEST_DB};

dies_ok( sub { Head::Ural::Profiles->new() }, 'Empty constructor');

my $t = Test::Mojo->new('Head');

my $p = Head::Ural::Profiles->new($t->app);
isa_ok($p, 'Head::Ural::Profiles');


is($p->exist('gwtest1'), 1, 'gwtest1 profile exists');
is($p->exist('asdfg'), 0, 'asdfg profile not exist');

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
