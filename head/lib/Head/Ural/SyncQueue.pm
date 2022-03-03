package Head::Ural::SyncQueue;
use Mojo::Base -base;

use Carp;
use Mojo::Promise;
use Mojo::mysql;
use NetAddr::IP::Lite;
use Head::Ural::Profiles qw(split_agent_subsys);

# Hint: use the following subquery to get flagged status of the deivce
#
# IF(EXISTS (SELECT 1 FROM sync_flags sf WHERE sf.device_id = devices.id), 1, 0) AS flagged
#

# new constructor
# my $obj = Head::Ural::SyncQueue->new();
# dies on errors
sub new {
  my ($class, $app, %opt) = @_;
  croak 'App parameter required!' unless $app;
  my $self = bless {
    app => $app,
  }, $class;
  #say 'Ural::SyncQueue constructor!';

  return $self;
}


# add new flag to queue
# uses external $db parameter, to call this function inside transaction
# $rows_inserted = $obj->set_flag($db, $device_id, 'plk')
# dies on errors
sub set_flag {
  my ($self, $db, $device_id, $profile) = @_;
  croak 'Bad set_flag parameter!' unless defined $db && defined $device_id && defined $profile;

  my $results = eval { $db->query("INSERT INTO sync_flags (device_id, agent_id) \
SELECT ?, a.id FROM profiles_agents a \
INNER JOIN profiles p ON a.profile_id = p.id \
WHERE p.profile = ? ORDER BY a.id",
    $device_id,
    $profile
  ) };
  croak "Set new flag database error: $@" unless $results;
  return $results->affected_rows;
}


# call callback sub for first 5 active flags in queue
# $obj->get_flags(sub { my ($device_id, $profile, $agent_url) = @_; ...use it... });
# returns 1, dies on database error.
sub get_flags {
  my ($self, $cb) = @_;
  my $db = $self->{app}->mysql_inet->db;

  my $results = eval { $db->query("SELECT sf.device_id, p.profile, a.url \
FROM sync_flags sf \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
INNER JOIN profiles p ON a.profile_id = p.id \
ORDER BY sf.id ASC LIMIT 5") };
  die "Database error (get_flags): $@\n" unless $results;

  while (my $n = $results->hash) {
    $cb->(
      $n->{device_id},
      $n->{profile},
      $n->{url}
    )
  }

  return 1;
}


# delete flags from queue (asyncronously)
# uses external $db parameter, to call this function inside transaction
# $promise = $obj->remove_flags_p($db, $device_id, $subsys, $profiles_array_ref)
#
# $obj->remove_flags_p($db, $device_id, $subsys, $profiles_array_ref)
# ->then(sub {my $affected_rows = shift;...success...})
# ->catch(sub {my $err = shift;...report $err...});
sub remove_flags_p {
  my ($self, $db, $id, $subsys, $profs) = @_;
  croak 'Bad arguments' unless defined $db and $id and $subsys and $profs;

  my ($agent_type) = split_agent_subsys($subsys);
  return Mojo::Promise->reject("device id $id bad subsys parameter $subsys") unless $agent_type;

  my $profile_rule = q{};
  for (@$profs) {
    if ($profile_rule eq q{}) { # first
      $profile_rule = 'profile IN ('.$db->quote($_);
    } else { # second etc
      $profile_rule .= ','.$db->quote($_);
    }
  }
  $profile_rule .= ') AND' if $profile_rule ne q{};
  #$self->log->debug("WHERE rule: *$profile_rule*");

  # delete sync_flags
  $db->query_p("DELETE sf FROM sync_flags sf \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
INNER JOIN profiles p ON a.profile_id = p.id \
WHERE $profile_rule \
sf.device_id = ? AND (a.type = ? OR a.type = ?)",
    $id,
    $subsys,
    $agent_type)
  ->then(sub {
    my $results = shift;
    return Mojo::Promise->resolve($results->affected_rows);
  });
}


# query sync queue status asyncronously (in /ui/syncqueue/status format)
# $resolved_or_rejected_promise = $obj->status_p();
#
# $obj->status_p
# ->then(sub {my $j = shift;...use $j...})
# ->catch(sub {my $err = shift;...report $err...});
sub status_p {
  $_[0]->{app}->mysql_inet->db->query_p("SELECT sf.device_id, d.name, d.ip, \
c.cn AS client_cn, \
d.profile, p.name AS profile_name, \
sf.agent_id, a.name AS agent_name, a.type AS agent_type \
FROM sync_flags sf \
INNER JOIN devices d ON sf.device_id = d.id \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
LEFT OUTER JOIN clients c ON d.client_id = c.id \
LEFT OUTER JOIN profiles p ON d.profile = p.profile \
ORDER BY sf.id ASC LIMIT 100")
  ->then(sub {
    my $results = shift;

    my $j = undef;
    if (my $d = $results->hashes) {
      $j = $d->map(sub { return eval { _build_syncqueue_rec($_) } })->compact;
    } else {
      return Mojo::Promise->reject('bad result');
    }

    return Mojo::Promise->resolve($j);
  });
}


# internal
# { syncqueue_rec_hash } = _build_syncqueue_rec( { hash_from_database } );
sub _build_syncqueue_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
  my $r = { ip => $ipo->addr };
  for (qw/profile agent_type/) {
    die 'Undefined syncqueue record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  my $name = $h->{name};
  my $agent_name = $h->{agent_name};
  $r->{name} = defined $name && $name ne q{} ? $name : "ID: $h->{device_id}";
  $r->{agent_name} = defined $agent_name && $agent_name ne q{} ? $agent_name : "ID: $h->{agent_id}";
  for (qw/client_cn profile_name/) {
    $r->{$_} = $h->{$_} if defined $h->{$_};
  }

  return $r;
}


1;
