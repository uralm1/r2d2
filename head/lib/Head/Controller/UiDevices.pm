package Head::Controller::UiDevices;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use NetAddr::IP::Lite;


sub deviceget {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  $self->render_later;

  $self->mysql_inet->db->query("SELECT d.id, d.name, d.desc, DATE_FORMAT(d.create_time, '%k:%i:%s %e-%m-%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, sum_limit_in, blocked, \
IF(EXISTS (SELECT 1 FROM sync_flags sf WHERE sf.device_id = d.id), 1, 0) AS flagged, \
d.profile, p.name AS profile_name, d.client_id AS client_id, c.type AS client_type, c.cn AS client_cn, c.login AS client_login \
FROM devices d INNER JOIN clients c ON d.client_id = c.id LEFT OUTER JOIN profiles p ON d.profile = p.profile \
WHERE d.id = ? AND d.client_id = ?", $device_id, $client_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, retrieving device', status => 503) if $err;

      if (my $rh = $results->hash) {
        my $dr = eval { _build_device_rec($rh) };
        return $self->render(text => 'Invalid attibute or IP', status => 503) unless $dr;
        $self->render(json => $dr);
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


# { device_rec_hash } = _build_device_rec( { hash_from_database } );
sub _build_device_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
  my $r = { ip => $ipo->addr };
  for (qw/id name desc create_time mac rt defjump speed_in speed_out no_dhcp qs limit_in sum_limit_in blocked flagged profile/) {
    die 'Undefined device record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  for (qw/profile_name client_id client_type client_cn client_login/) {
    $r->{$_} = $h->{$_} if defined $h->{$_};
  }
  return $r;
}


# edit client device submit
sub deviceput {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'client_device_record');

  return $self->render(text=>'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $device_id;

  my $ipo = NetAddr::IP::Lite->new($j->{ip});
  return $self->render(text=>'Bad ip', status => 503) unless $ipo;

  $self->log->debug($self->dumper($j));

  my $db = $self->mysql_inet->db;

  my $results = eval { $db->query("SELECT cn AS client_cn FROM clients \
WHERE id = ? AND type = 0", $client_id) };
  return $self->render(text => "Database error, searching client: $@", status => 503) unless $results;
  return $self->render(text => 'Client not found', status => 404) if ($results->rows < 1);

  my $client_cn = $results->array->[0];

  $results->finish;

  # start transaction
  my $tx = eval { $db->begin };
  return $self->render(text => "Database error, transaction failure: $@", status => 503) unless $tx;

  $results = eval { $db->query("UPDATE devices \
SET name = ?, devices.desc = ?, ip = ?, mac = ?, no_dhcp = ?, rt = ?, defjump = ?, speed_in = ?, speed_out = ?, qs = ?, limit_in = ?, sync_flags = 15 \
WHERE id = ? AND client_id = ? AND profile = ?",
    $j->{name},
    $j->{desc} // '',
    scalar($ipo->numeric),
    $j->{mac},
    $j->{no_dhcp},
    $j->{rt},
    $j->{defjump},
    $j->{speed_in},
    $j->{speed_out},
    $j->{qs},
    $j->{limit_in},
    $device_id, $client_id, $j->{profile}
  ) };
  return $self->render(text => "Database error, updating device: $@", status => 503) unless $results;

  if ($results->affected_rows == 0) {
    $self->dblog->info("UI: Device id $device_id not updated");
    return $self->render(text => "Device id $device_id not found or profile invalid", status => 404);
  }

  # insert sync flags
  my $err = eval { $self->syncqueue->set_flag(
    $db, $device_id, $j->{profile},
    {name => $j->{name}, client_cn => $client_cn, ip => $j->{ip}, _s => 'deviceput'}
  ) };
  return $self->render(text => $@, status => 503) unless defined $err;

  eval { $tx->commit };
  return $self->render(text => "Database error, transaction commit failure: $@", status => 503) if $@;

  # finished
  $self->dblog->info("UI: Device id $device_id updated successfully");
  $self->rendered(200);
}


# new client device submit
sub devicepost {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'client_device_record');

  return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

  my $ipo = NetAddr::IP::Lite->new($j->{ip});
  return $self->render(text=>'Bad ip', status => 503) unless $ipo;

  $self->log->debug($self->dumper($j));

  my $db = $self->mysql_inet->db;

  my $results = eval { $db->query("SELECT cn AS client_cn FROM clients \
WHERE id = ? AND type = 0", $client_id) };
  return $self->render(text => "Database error, searching client: $@", status => 503) unless $results;
  return $self->render(text => 'Client not found', status => 404) if ($results->rows < 1);

  my $client_cn = $results->array->[0];

  $results->finish;

  # start transaction
  my $tx = eval { $db->begin };
  return $self->render(text => "Database error, transaction failure: $@", status => 503) unless $tx;

  # deprecated sync_flags field is set via field default value
  $results = eval { $db->query("INSERT INTO devices \
(name, devices.desc, create_time, ip, mac, no_dhcp, rt, defjump, speed_in, speed_out, qs, limit_in, sum_limit_in, profile, notified, blocked, bot, client_id) \
VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?)",
    $j->{name},
    $j->{desc} // '',
    scalar($ipo->numeric),
    $j->{mac},
    $j->{no_dhcp},
    $j->{rt},
    $j->{defjump},
    $j->{speed_in},
    $j->{speed_out},
    $j->{qs},
    $j->{limit_in},
    $j->{limit_in},
    $j->{profile},
    $client_id
  ) };
  return $self->render(text => "Database error, inserting device: $@", status => 503) unless $results;

  my $last_id = $results->last_insert_id;

  $results = eval { $db->query("INSERT INTO amonthly (device_id, date, m_in, m_out) \
VALUES (?, CURDATE(), 0, 0)", $last_id) };
  return $self->render(text => "Database error, inserting amonthly: $@", status => 503) unless $results;

  # insert sync flags
  my $err = eval { $self->syncqueue->set_flag(
    $db, $last_id, $j->{profile},
    {name => $j->{name}, client_cn => $client_cn, ip => $j->{ip}, _s => 'devicepost'}
  ) };
  return $self->render(text => $@, status => 503) unless defined $err;

  eval { $tx->commit };
  return $self->render(text => "Database error, transaction commit failure: $@", status => 503) if $@;

  # finished
  $self->dblog->info("UI: Device id $last_id added successfully");
  $self->render(text => $last_id);
}


# change device client
sub devicepatchmove {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  return unless my $j = $self->json_content($self->req);

  $self->log->debug($self->dumper($j));
  return $self->render(text => 'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $client_id;
  return $self->render(text => 'Bad format', status => 503) unless exists($j->{newid}) && $j->{newid} =~ /^\d+$/;
  return $self->render(text => 'Same client', status => 503) if $j->{newid} == $client_id;

  $self->render_later;

  $self->mysql_inet->db->query("UPDATE devices \
SET client_id = ? \
WHERE id = ? AND client_id = ? AND EXISTS (SELECT 1 FROM clients WHERE type = 0 AND clients.id = ?)",
    $j->{newid},
    $device_id,
    $client_id,
    $j->{newid} =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, moving device: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Device id $device_id moved successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Device id $device_id not moved");
        $self->render(text => "Device id $device_id not found or client invalid", status => 404);
      }
    }
  );
}


# change device limit
sub devicepatchlimit {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'limit_record');

  $self->log->debug($self->dumper($j));

  $self->render_later;

  my $sql;
  my @sql_params;
  if ($j->{add_sum}) {
    $sql = "UPDATE devices SET qs = ?, sum_limit_in = sum_limit_in + ? \
WHERE id = ? AND client_id = ?";
    @sql_params = ($j->{qs}, $j->{limit_in}, $device_id, $client_id);
  } elsif ($j->{reset_sum}) {
    $sql = "UPDATE devices SET qs = ?, limit_in = ?, sum_limit_in = ? \
WHERE id = ? AND client_id = ?";
    @sql_params = ($j->{qs}, $j->{limit_in}, $j->{limit_in}, $device_id, $client_id);
  } else {
    $sql = "UPDATE devices SET qs = ?, limit_in = ? \
WHERE id = ? AND client_id = ?";
    @sql_params = ($j->{qs}, $j->{limit_in}, $device_id, $client_id);
  }

  $self->mysql_inet->db->query($sql, @sql_params =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating device limit: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Device id $device_id limit updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Device id $device_id limit not updated");
        $self->render(text => "Device id $device_id not found or client invalid", status => 404);
      }
    }
  );
}


# delete device submit
sub devicedelete {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  #$self->log->debug("Deleting device id: $device_id");

  my $db = $self->mysql_inet->db;

  # get deivce profile
  my $results = eval { $db->query("SELECT name, ip, profile, cn AS client_cn \
FROM devices INNER JOIN clients ON client_id = clients.id \
WHERE devices.id = ? AND client_id = ?", $device_id, $client_id) };
  return $self->render(text => "Database error, getting client: $@", status => 503) unless $results;
  return $self->render(text => "Device id $device_id not found", status => 404) if $results->rows < 1;

  my $n = $results->hash;
  my %ext = %$n;

  $results->finish;

  # start transaction
  my $tx = eval { $db->begin };
  return $self->render(text => "Database error, transaction failure: $@", status => 503) unless $tx;

  $results = eval { $db->query("DELETE FROM devices WHERE id = ? AND client_id = ?",
    $device_id, $client_id) };
  return $self->render(text => "Database error, deleting device: $@", status => 503) unless $results;

  my $afr = $results->affected_rows;

  # insert sync flags
  if ($afr > 0) {
    my $err = eval { $self->syncqueue->set_flag(
      $db, $device_id, $ext{profile},
      {name => $ext{name}, client_cn => $ext{client_cn}, ip => $ext{ip}, _s => 'devicedelete'}
    ) };
    return $self->render(text => $@, status => 503) unless defined $err;
  }

  eval { $tx->commit };
  return $self->render(text => "Database error, transaction commit failure: $@", status => 503) if $@;

  # finished
  if ($afr > 0) {
    $self->dblog->info("UI: Device id $device_id deleted successfully");
    $self->rendered(200);
  } else {
    $self->dblog->info("UI: Device id $device_id not deleted. This should not happen.");
    $self->render(text => "Device id $device_id not deleted", status => 503);
  }
}


1;
