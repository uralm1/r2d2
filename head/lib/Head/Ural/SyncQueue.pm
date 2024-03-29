package Head::Ural::SyncQueue;
use Mojo::Base -base;

use Carp;
use Mojo::Promise;
use Mojo::mysql;
use Mojo::JSON qw(from_json);
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


# add new flags to queue
# uses external $db parameter, to call this function inside transaction
# [id1,... idn] = $obj->set_flag($db, $device_id, 'plk')
# [id1,... idn] = $obj->set_flag($db, $device_id, 'plk',
#   { name => 'Comp', client_cn => 'FIO', ip => integer_format_ip })
# return ref to array of inserted flag ids,
# dies on errors
sub set_flag {
  my ($self, $db, $device_id, $profile, $ext_data) = @_;
  croak 'Bad set_flag() parameter!' unless defined $db && defined $device_id && defined $profile;

  my $ext_data_insert = undef;
  if (defined $ext_data) {
    croak 'ext_data parameter is invalid' if ref $ext_data ne 'HASH';
    for (keys %$ext_data) {
      croak 'Unsupported ext_data key' unless /^name|client_cn|ip|_s$/;
    }
    $ext_data_insert = {json => $ext_data};
  }

  my $results = eval { $db->query("SELECT a.id FROM profiles_agents a \
INNER JOIN profiles p ON a.profile_id = p.id \
WHERE p.profile = ? ORDER BY a.id", $profile) };
  die "Set new flag database error(select agents): $@\n" unless $results;

  my $a = $results->arrays->map(sub { $_->[0] });
  $results->finish;

  my @flags_ids;
  $a->each(sub {
    $results = eval { $db->query("INSERT INTO sync_flags (device_id, agent_id, ext_data) \
VALUES (?, ?, ?)", $device_id, $_, $ext_data_insert) };
    die "Set new flag database error (insert): $@\n" unless $results;
    push @flags_ids, $results->last_insert_id;
  });

  return \@flags_ids;
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
  #$self->{app}->log->debug("WHERE profile rule: *$profile_rule*");

  # query flags to delete
  $db->query_p("SELECT sf.id FROM sync_flags sf \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
INNER JOIN profiles p ON a.profile_id = p.id \
WHERE $profile_rule \
sf.device_id = ? AND (a.type = ? OR a.type = ?) ORDER BY sf.id LIMIT 50",
    $id,
    $subsys,
    $agent_type
  )->then(sub {
    my $results = shift;

    my $c = $results->arrays;
    my $c_size = $c->size;
    $c = $c->head($c_size > 1 ? $c_size - 1 : $c_size);

    my $id_rule = q{};
    $c->each(sub {
      if ($id_rule eq q{}) { # first
        $id_rule = "id IN ($_->[0]";
      } else { # second etc
        $id_rule .= ",$_->[0]";
      }
    });

    if ($id_rule ne q{}) {
      $id_rule .= ')';
      #$self->{app}->log->debug("WHERE id rule: *$id_rule*");

      # delete sync_flags, return promise
      $db->query_p("DELETE FROM sync_flags WHERE $id_rule");
    } else {
      return undef;
    }

  })->then(sub {
    my $results = shift;
    if ($results) {
      return $results->affected_rows;
    } else {
      return 0;
    }
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
sf.agent_id, a.name AS agent_name, a.type AS agent_type, \
sf.ext_data \
FROM sync_flags sf \
LEFT OUTER JOIN devices d ON sf.device_id = d.id \
LEFT OUTER JOIN clients c ON d.client_id = c.id \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
INNER JOIN profiles p ON a.profile_id = p.id \
ORDER BY sf.id ASC LIMIT 100")
  ->then(sub {
    my $results = shift;

    my $j = undef;
    if (my $d = $results->hashes) {
      $j = $d->map(sub { return eval { _build_syncqueue_rec($_) } })->compact;
    } else {
      return Mojo::Promise->reject('bad result');
    }

    return $j;
  });
}


# internal
# { syncqueue_rec_hash } = _build_syncqueue_rec( { hash_from_database } );
sub _build_syncqueue_rec {
  my $h = shift;

  my $ext_data = {name => "ID: $h->{device_id}", client_cn => 'н/д', ip => 0};
  if (defined $h->{ext_data}) {
    my $t = eval { from_json $h->{ext_data} };
    if (defined $t && ref $t eq 'HASH') {
      for (qw/name client_cn ip/) {
        $ext_data->{$_} = $t->{$_} if exists $t->{$_};
      }
    }
  }

  my $ipo = NetAddr::IP::Lite->new($h->{ip} // $ext_data->{ip}) || die 'IP address failure';
  my $r = { ip => $ipo->addr };
  for (qw/profile profile_name agent_type/) {
    die 'Undefined syncqueue record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  my $name = $h->{name};
  my $agent_name = $h->{agent_name};
  my $client_cn = $h->{client_cn};
  $r->{name} = defined $name && $name ne q{} ? $name : $ext_data->{name};
  $r->{agent_name} = defined $agent_name && $agent_name ne q{} ? $agent_name : "ID: $h->{agent_id}";
  $r->{client_cn} = defined $client_cn && $client_cn ne q{} ? $client_cn : $ext_data->{client_cn};

  return $r;
}


1;
