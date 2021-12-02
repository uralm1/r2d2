package Head::Controller::UiServers;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use NetAddr::IP::Lite;


sub serverget {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  $self->render_later;
  # FIXME sync_flags field is deprecated
  $self->mysql_inet->db->query("SELECT c.id, cn, c.desc, DATE_FORMAT(c.create_time, '%k:%i:%s %e-%m-%y') AS create_time, email, c.email_notify, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, IF(sync_flags > 0, 1, 0) AS flagged, d.profile, p.name AS profile_name \
FROM clients c INNER JOIN devices d ON d.client_id = c.id \
LEFT OUTER JOIN profiles p ON d.profile = p.profile \
WHERE type = 1 AND c.id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, retrieving server', status => 503) if $err;

      if (my $rh = $results->hash) {
        my $sr = eval { _build_server_rec($rh) };
        return $self->render(text => 'Invalid IP or attribute', status => 503) unless $sr;
        $self->render(json => $sr);
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


# { servers_rec_hash } = _build_server_rec( { hash_from_database } );
sub _build_server_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
  my $sr = { ip => $ipo->addr };
  for (qw/id cn desc create_time email email_notify mac rt defjump speed_in speed_out no_dhcp qs limit_in blocked flagged profile/) {
    die 'Undefined server record attribute' unless exists $h->{$_};
    $sr->{$_} = $h->{$_};
  }
  for (qw/profile_name/) {
    $sr->{$_} = $h->{$_} if defined $h->{$_};
  }
  return $sr;
}


# edit server submit
sub serverput {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'server_record');

  return $self->render(text=>'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $id;

  my $ipo = NetAddr::IP::Lite->new($j->{ip});
  return $self->render(text=>'Bad ip', status => 503) unless $ipo;

  $self->log->debug($self->dumper($j));
  $self->render_later;

  # FIXME sync_flags field is deprecated
  $self->mysql_inet->db->query("UPDATE clients c INNER JOIN devices d ON d.client_id = c.id \
SET cn = ?, c.desc = ?, name = 'Подключение сервера', d.desc = '', email = ?, c.email_notify = ?, ip = ?, mac = ?, no_dhcp = ?, rt = ?, defjump = ?, speed_in = ?, speed_out = ?, qs = ?, limit_in = ?, sync_flags = 15 \
WHERE c.type = 1 AND c.id = ?",
    $j->{cn},
    $j->{desc} // '',
    $j->{email} // '',
    $j->{email_notify} // 1,
    scalar($ipo->numeric),
    $j->{mac},
    $j->{no_dhcp},
    $j->{rt},
    $j->{defjump},
    $j->{speed_in},
    $j->{speed_out},
    $j->{qs},
    $j->{limit_in},
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating server: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Server id $id updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Server id $id not updated");
        $self->render(text => "Server id $id not found", status => 404);
      }
    }
  );
}


# new server submit
sub serverpost {
  my $self = shift;
  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'server_record');

  return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

  my $ipo = NetAddr::IP::Lite->new($j->{ip});
  return $self->render(text => 'Bad ip', status => 503) unless $ipo;

  $self->log->debug($self->dumper($j));

  # start transaction
  my $db = $self->mysql_inet->db;
  my $tx = eval { $db->begin };
  return $self->render(text => "Database error, transaction failure: $@", status => 503) unless $tx;

  my $results = eval { $db->query("INSERT INTO clients \
(create_time, type, guid, login, clients.desc, cn, email, email_notify, lost) \
VALUES (NOW(), 1, '', '', ?, ?, ?, ?, 0)",
    $j->{desc} // '',
    $j->{cn},
    $j->{email} // '',
    $j->{email_notify} // 1
  ) };
  return $self->render(text => "Database error, inserting servers: $@", status => 503) unless $results;

  my $last_id = $results->last_insert_id;

  $results = eval { $db->query("INSERT INTO devices \
(name, devices.desc, create_time, ip, mac, no_dhcp, rt, defjump, speed_in, speed_out, qs, limit_in, sum_limit_in, profile, notified, blocked, bot, client_id) \
VALUES ('Подключение сервера', '', NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 1, ?)",
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
    $last_id
  ) };
  return $self->render(text => "Database error, inserting devices: $@", status => 503) unless $results;

  eval { $tx->commit };
  return $self->render(text => "Database error, transaction commit failure: $@", status => 503) if $@;

  # finished
  $self->dblog->info("UI: Server id $last_id added successfully");
  $self->render(text => $last_id);
}


# delete server submit
sub serverdelete {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  #$self->log->debug("Deleting id: $id");

  $self->render_later;

  $self->mysql_inet->db->query("DELETE clients, devices FROM clients INNER JOIN devices ON client_id = clients.id \
WHERE clients.type = 1 AND clients.id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, deleting server: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Server id $id deleted successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Server id $id not deleted");
        $self->render(text => "Server id $id not found", status => 404);
      }
    }
  );
}


1;
