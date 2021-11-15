package Head::Controller::UiClients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;


sub clientget {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status => 404) unless (defined($id) && $id =~ /^\d+$/);

  $self->render_later;

  $self->mysql_inet->db->query("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, cn, email, email_notify \
FROM clients c WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, retrieving client: $err", status => 503) if $err;

      if (my $rh = $results->hash) {
        my $cl = eval { _build_client_rec($rh) };
        return $self->render(text => 'Client attribute error', status => 503) unless $cl;
        $results->finish;

        $db->query("SELECT d.id, d.name, d.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, d.profile, p.name AS profile_name \
FROM devices d LEFT OUTER JOIN profiles p ON d.profile = p.profile WHERE d.client_id = ? \
ORDER BY d.id ASC LIMIT 20", $cl->{id} =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => "Database error, retrieving devices: $err", status => 503) if $err;

          my $devs = undef;
          if (my $d = $results->hashes) {
            $devs = $d->map(sub { return eval { Head::Controller::UiDevices::_build_device_rec($_) } })->compact;
          } else {
            return $self->render(text => 'Database error, bad result', status=>503);
          }

          $cl->{devices} = $devs;

          $self->render(json => $cl);
        }); # inner query
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  ); # outer query
}


# { clients_rec_hash } = _build_client_rec( { hash_from_database } );
sub _build_client_rec {
  my $h = shift;
  my $r = {};
  for (qw/id type guid login desc create_time cn email email_notify/) {
    die 'Undefined client record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  return $r;
}


# new client submit
sub clientpost {
  my $self = shift;
  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'client_record');

  return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

  $self->log->debug($self->dumper($j));
  $self->render_later;

  $self->mysql_inet->db->query("INSERT INTO clients \
(create_time, type, guid, login, clients.desc, cn, email, email_notify, lost) \
VALUES (NOW(), 0, ?, ?, ?, ?, ?, ?, 0)",
    $j->{guid},
    $j->{login},
    $j->{desc} // '',
    $j->{cn},
    $j->{email} // '',
    $j->{email_notify} // 1 =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, inserting client: $err", status => 503) if $err;

      my $last_id = $results->last_insert_id;
      $self->dblog->info("UI: Client id $last_id added successfully");
      $self->render(text => $last_id);
    }
  );
}


# edit client submit
sub clientput {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'client_record');

  $self->log->debug($self->dumper($j));
  return $self->render(text => 'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $id;

  $self->render_later;

  $self->mysql_inet->db->query("UPDATE clients \
SET guid = ?, login = ?, clients.desc = ?, cn = ?, email = ?, email_notify = ?, lost = 0 \
WHERE type = 0 AND id = ?",
    $j->{guid},
    $j->{login},
    $j->{desc} // '',
    $j->{cn},
    $j->{email} // '',
    $j->{email_notify} // 1,
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating client: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Client id $id updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Client id $id not updated");
        $self->render(text => "Client id $id not found", status => 404);
      }
    }
  );
}


# delete client submit
sub clientdelete {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  #$self->log->debug("Deleting id: $id");

  $self->render_later;

  $self->mysql_inet->db->query("SELECT id FROM devices WHERE client_id = ?",
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, checking devices: $err", status => 503) if $err;
      return $self->render(text => 'Refused, client devices exist', status => 400) if ($results->rows > 0);

      $results->finish;

      $db->query("DELETE FROM clients \
    WHERE type = 0 AND id = ?", $id =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => "Database error, deleting client: $err", status => 503) if $err;

          if ($results->affected_rows > 0) {
            $self->dblog->info("UI: Client id $id deleted successfully");
            $self->rendered(200);
          } else {
            $self->dblog->info("UI: Client id $id not deleted");
            $self->render(text => "Cilent id $id not found", status => 404);
          }
        }
      ); # inner query
    }
  ); # outer query
}


# edit client description and email_notify submit
sub clientpatch0 {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  return unless my $j = $self->json_content($self->req);

  #$self->log->debug($self->dumper($j));
  return $self->render(text => 'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $id;
  return $self->render(text => 'Bad format', status => 503)
    unless defined $j->{desc} and defined $j->{email_notify} and $j->{email_notify} =~ /^[01]$/;

  $self->render_later;

  $self->mysql_inet->db->query("UPDATE clients \
SET clients.desc = ?, email_notify = ? \
WHERE type = 0 AND id = ?",
    $j->{desc},
    $j->{email_notify},
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating client description/notify: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Client id $id description/notify updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Client id $id description/notify not updated");
        $self->render(text => "Client id $id not found", status => 404);
      }
    }
  );
}


# edit client email_notify by login submit
sub clientpatch1bylogin {
  my $self = shift;

  return unless my $j = $self->json_content($self->req);

  $self->log->debug($self->dumper($j));

  my $login = $j->{login};
  return $self->render(text => 'Bad format', status => 503)
    unless defined $login and $login ne ''
      and defined $j->{email_notify} and $j->{email_notify} =~ /^[01]$/;

  $self->render_later;

  $self->mysql_inet->db->query("UPDATE clients \
SET email_notify = ? \
WHERE type = 0 AND login = ?",
    $j->{email_notify},
    $login =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating client email_notify: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Client $login email_notify updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Client $login email_notify not updated");
        $self->render(text => "Client not found", status => 404);
      }
    }
  );
}


1;
