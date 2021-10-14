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

  $self->mysql_inet->db->query("SELECT id, name, d.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
FROM devices d WHERE id = ? AND client_id = ?", $device_id, $client_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, retrieving device', status => 503) if $err;

      if (my $rh = $results->hash) {
        my $dr = eval { _build_device_rec($rh) };
        return $self->render(text => 'Invalid IP', status => 503) unless $dr;
        $self->render(json => $dr);
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


# { devices_rec_hash } = _build_device_rec( { hash_from_database } );
sub _build_device_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
  my $r = { ip => $ipo->addr };
  for (qw/id name desc create_time mac rt defjump speed_in speed_out no_dhcp qs limit_in blocked profile/) {
    die 'Undefined device record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
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
  $self->render_later;

  $self->mysql_inet->db->query("UPDATE devices \
SET name = ?, devices.desc = ?, ip = ?, mac = ?, no_dhcp = ?, rt = ?, defjump = ?, speed_in = ?, speed_out = ?, qs = ?, limit_in = ? \
WHERE id = ? AND client_id = ? AND EXISTS (SELECT 1 FROM clients WHERE clients.id = ? AND type = 0)",
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
    $device_id, $client_id, $client_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating device: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Device id $device_id updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Device id $device_id not updated");
        $self->render(text => "Device id $device_id not found or client invalid", status => 404);
      }
    }
  );
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
  $self->render_later;

  $self->mysql_inet->db->query("SELECT 1 FROM clients WHERE id = ? AND type = 0",
    $client_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, searching client: $err", status => 503) if $err;
      return $self->render(text => 'Client not found', status => 404) if ($results->rows < 1);

      $results->finish;

      $db->query("INSERT INTO devices \
(name, devices.desc, create_time, ip, mac, no_dhcp, rt, defjump, speed_in, speed_out, qs, limit_in, sum_limit_in, profile, email_notify, notified, blocked, bot, client_id) \
VALUES (?, ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 1, ?)",
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
        $client_id =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => "Database error, inserting device: $err", status => 503) if $err;

          my $last_id = $results->last_insert_id;
          $self->dblog->info("UI: Device id $last_id added successfully");
          $self->render(text => $last_id);
        }
      ); # inner query
    }
  ); # outer query
}


# change device client
sub devicepatch {
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


# delete device submit
sub devicedelete {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  #$self->log->debug("Deleting device id: $device_id");

  $self->render_later;

  $self->mysql_inet->db->query("DELETE FROM devices WHERE id = ? AND client_id = ?",
    $device_id, $client_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, deleting device: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Device id $device_id deleted successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Device id $device_id not deleted");
        $self->render(text => "Device id $device_id not found", status => 404);
      }
    }
  );
}


1;