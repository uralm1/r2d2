package Head::Ural::Profiles;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;

# agent hash structure:
# {
#   name => 'Agent name',
#   type => 'gwsyn',
#   url => 'https://1.2.3.4:2275',
#   block => 1 or 0,
# }

# new constructor
# my $obj = Head::Ural::Profiles->new();
# dies on errors
sub new {
  my ($class, $app, %opt) = @_;
  croak 'App parameter required!' unless $app;
  my $self = bless {
    app => $app,
  }, $class;
  #say 'Ural::Profiles constructor!';

  return $self;
}


# $obj->eachagent('this_profile_key', sub { my ($profile_key, $agent_key, $agent) = @_; say "$profile_key => $agent->{name}" });
# $obj->eachagent(sub { my ($profile_key, $agent_key, $agent) = @_; say "$profile_key => $agent->{name}" });
# returns 1 if ok, 0 - database error.
sub eachagent {
  my ($self, $pk, $cb) = @_;
  my $db = $self->{app}->mysql_inet->db;
  my $results;
  if (!defined $pk or ref $pk eq 'CODE') {
    $cb = $pk if defined $pk;
    # multiple profiles
    $results = eval { $db->query("SELECT p.profile, a.id, a.name, a.type, a.url, a.block \
FROM profiles_agents a INNER JOIN profiles p ON a.profile_id = p.id ORDER BY p.profile, a.id") };

  } else {
    # one profile
    $results = eval { $db->query("SELECT p.profile, a.id, a.name, a.type, a.url, a.block \
FROM profiles_agents a INNER JOIN profiles p ON a.profile_id = p.id \
WHERE p.profile = ? ORDER BY a.id", $pk) };

  }
  unless ($results) {
    carp 'Database error (eachagent)';
    return 0;
  }
  while (my $n = $results->hash) {
    $cb->(
      $n->{profile},
      $n->{id},
      { name => $n->{name} // 'Имя не задано',
        type => $n->{type},
        url => $n->{url},
        block => $n->{block} ? 1 : 0
      }
    )
  }

  return 1;
}


# check profile exists
# 0|1 = $obj->exist($profile_key)
sub exist {
  my ($self, $profile_key) = @_;
  my $results = eval {
    $self->{app}->mysql_inet->db->query('SELECT 1 FROM profiles WHERE profile = ?',
      $profile_key)
  };
  unless ($results) {
    carp 'Database error (exists)';
    return 0;
  }
  $results->rows < 1 ? 0 : 1;
}


# set state, status, update lastchecks
# ''|'error string' = $obj->setcheck($profile_key, $agent_key, $state, $status)
sub setcheck {
  my ($self, $profile_key, $agent_key, $state, $status) = @_;
  my $db = $self->{app}->mysql_inet->db;

  # database first
  my $results = eval { $db->query("UPDATE profiles_agents \
SET lastcheck = NOW(), state = ?, status = ? \
WHERE id = ?",
    $state,
    $status,
    $agent_key
  )};
  return 'Profile agent update error' unless $results;

  $results = eval { $db->query("UPDATE profiles \
SET lastcheck = NOW() \
WHERE profile = ?",
    $profile_key
  )};
  return 'Profile update error' unless $results;
  return q{};
}


1;
