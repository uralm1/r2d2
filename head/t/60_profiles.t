use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Test::Mojo;

use Head::Ural::Profiles;

dies_ok( sub { Head::Ural::Profiles->new() }, 'Empty constructor');

my $_profs = {
  test1 => {
    name => 'Testing profile 1',
    agents => {
      '1' => { name => 'Agent1', type => 'gwsyn', url => '111' },
      '2' => { name => 'Agent2', type => 'rtsyn', url => '222' },
    }
  },
  test2 => {
    name => 'Testing profile 2',
    agents => {
      '3' => { name => 'Agent3', type => 'gwsyn', url => '333' },
    }
  }
};

my $t = Test::Mojo->new('Head');

my $p = Head::Ural::Profiles->new($t->app, dont_copy_config_to_db => 1);
isa_ok($p, 'Head::Ural::Profiles');

diag explain $p->hash;
is(ref $p->hash, 'HASH', 'Loaded profiles hash');

$p->_test_assign($_profs);
is_deeply($p->hash, $_profs, 'Assigned profiles hash');

$p->each(sub {
  my ($profile_key, $profile) = @_;
  #say "$profile_key => $profile->{name}";
  is($profile->{name}, $_profs->{$profile_key}{name}, "Testing each, key: $profile_key");
});

my $r = $p->eachagent(sub {
  my ($profile_key, $agent_key, $agent) = @_;
  #say "$agent_key => $agent->{name}";
  is($agent->{name}, $_profs->{$profile_key}{agents}{$agent_key}{name},
    "Testing eachagent, profilekey: $profile_key, agentkey: $agent_key");
});
is($r, 1, "eachagent1 returned 1");

$r = $p->eachagent('test2', sub {
  my ($profile_key, $agent_key, $agent) = @_;
  #say "$agent_key => $agent->{name}";
  is($profile_key, 'test2', "Testing eachagent profile 'test2'");
  is($agent->{name}, $_profs->{$profile_key}{agents}{$agent_key}{name},
    "Testing eachagent, profilekey: $profile_key, agentkey: $agent_key");
});
is($r, 1, "eachagent2 returned 1");

$r = $p->eachagent('test3', sub {
  my ($profile_key, $agent_key, $agent) = @_;
  say "$agent_key => $agent->{name}";
});
is($r, 0, "eachagent3 returned 0");


done_testing();
