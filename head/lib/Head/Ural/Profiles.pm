package Head::Ural::Profiles;
use Mojo::Base -base;

use Carp;
use Mojo::Promise;
use Mojo::mysql;

use Exporter qw(import);
our @EXPORT_OK = qw(split_agent_subsys);

# agent hash structure:
# {
#   name => 'Agent name',
#   type => 'gwsyn' or 'dhcpsyn@plksrv1',
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
# returns 1, dies on database error.
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
  croak 'Database error (eachagent)' unless $results;

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


# not an object metod
# my ($type, $hostname) = split_agent_subsys($type_or_subsys)
sub split_agent_subsys {
  my $t = shift;
  my ($type, $hostname) = (q{}, q{});
  if (defined $t && $t =~ /^([^@]+)(?:@(.*))?$/) {
    $type = $1;
    $hostname = $2 if defined $2;
  }
  return ($type, $hostname);
}


# check profile exist
# 0|1 = $obj->exist($profile_key)
# dies on error
sub exist {
  my ($self, $profile_key) = @_;
  my $results = eval {
    $self->{app}->mysql_inet->db->query('SELECT 1 FROM profiles WHERE profile = ?',
      $profile_key)
  };
  croak "Database error (exists): $@" unless $results;

  $results->rows < 1 ? 0 : 1;
}


# set state, status, update lastchecks
# $obj->set_check($profile_key, $agent_key, $state, $status)
# return true, dies on error
sub set_check {
  my ($self, $profile_key, $agent_key, $state, $status) = @_;
  my $db = $self->{app}->mysql_inet->db;

  my $results = eval { $db->query("UPDATE profiles_agents \
SET lastcheck = NOW(), state = ?, status = ? \
WHERE id = ?",
    $state,
    $status,
    $agent_key
  )};
  croak "Profile agent update error\n" unless $results;

  $results = eval { $db->query("UPDATE profiles \
SET lastcheck = NOW() \
WHERE profile = ?",
    $profile_key
  )};
  croak "Profile update error\n" unless $results;
  return 1;
}


# query profiles as a hash asyncronously (in /ui/profiles hash format)
# $resolved_or_rejected_promise = $obj->hash_p()
#
# $obj->hash_p
# ->then(sub {my $j = shift;...use $j...})
# ->catch(sub {my $err = shift;...report $err...});
sub hash_p {
  $_[0]->{app}->mysql_inet->db->query_p('SELECT profile, name FROM profiles')
  ->then(sub {
    my $results = shift;

    my $j = {};
    while (my $n = $results->array) { $j->{$n->[0]} = $n->[1] }
    return Mojo::Promise->resolve($j);
  });
}


# query profiles count asyncronously
# $resolved_or_rejected_promise = $obj->count_p()
#
# $obj->count_p
# ->then(sub {my $c = shift;...use $c...})
# ->catch(sub {my $err = shift;...report $err...});
sub count_p {
  $_[0]->{app}->mysql_inet->db->query_p('SELECT COUNT(*) FROM profiles')
  ->then(sub {
    return Mojo::Promise->resolve(shift->array->[0]);
  });
}


# query profiles status asyncronously (in /ui/profiles/status "d" attribute format - array)
# $resolved_or_rejected_promise = $obj->status_p($lines_on_page, $current_page)
#
# $obj->status_p($lines_on_page, $current_page)
# ->then(sub {my $j = shift;...use $j...})
# ->catch(sub {my $err = shift;...report $err...});
sub status_p {
  my ($self, $lines_on_page, $page) = @_;
  my $db = $self->{app}->mysql_inet->db;

  my $profiles_p = $db->query_p("SELECT id, profile, name, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%y') AS lastcheck \
FROM profiles ORDER BY profile, id LIMIT ? OFFSET ?",
    $lines_on_page,
    ($page - 1) * $lines_on_page
  );

  my $agents_p = $db->query_p("SELECT id, profile_id, name, type, url, block, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%y') AS lastcheck, state, status \
FROM profiles_agents ORDER BY id");

  # return compound promise
  Mojo::Promise->all($profiles_p, $agents_p)
  ->then(sub {
    my ($profiles_p, $agents_p) = @_;

    # reconcile agents
    my %_ah;
    while (my $next = $agents_p->[0]->hash) {
      my $ag = eval { _build_system_agent_rec($next) };
      return Mojo::Promise->reject('System profile attribute error (agent)') unless $ag;
      push @{$_ah{ $next->{profile_id} }}, $ag;
    }

    my $j = [];
    while (my $next = $profiles_p->[0]->hash) {
      my $pr = eval { _build_system_profile_rec($next) };
      return Mojo::Promise->reject('System profile attribute error') unless $pr;

      $pr->{agents} = $_ah{ $next->{id} } // [];
      push @$j, $pr;
    }

    # success
    return Mojo::Promise->resolve($j);
  });
}


# internal
# { profile_rec_hash } = _build_system_profile_rec( { hash_from_database } );
sub _build_system_profile_rec {
  my $h = shift;
  my $r = {};
  for (qw/profile name lastcheck/) {
    die 'Undefined system profile record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  $r->{lastcheck} //= q{};
  return $r;
}


# internal
# { agent_rec_hash } = _build_system_agent_rec( { hash_from_database } );
sub _build_system_agent_rec {
  my $h = shift;
  my $r = {};
  for (qw/name type url block lastcheck state status/) {
    die 'Undefined system agent record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  $r->{lastcheck} //= '';
  return $r;
}


1;
