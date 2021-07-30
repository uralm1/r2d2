package Head::Controller::UiClients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;


sub clientget {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status => 404) unless (defined($id) && $id =~ /^\d+$/);

  $self->render_later;

  $self->mysql_inet->db->query("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, cn, email \
FROM clients c WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, retrieving client: $err", status => 503) if $err;

      if (my $rh = $results->hash) {
        my $cl = eval { _build_client_rec($rh) };
        return $self->render(text => 'Client attribute error', status => 503) unless $cl;
        $results->finish;

        $db->query("SELECT id, name, d.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
FROM devices d WHERE client_id = ? \
ORDER BY id ASC LIMIT 20", $cl->{id} =>
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
  for (qw/id type guid login desc create_time cn email/) {
    die 'Undefined client record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  return $r;
}


# new client submit
sub clientpost {
  my $self = shift;
  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return unless $self->json_validate($j, 'client_record');

    return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

    $self->log->debug($self->dumper($j));
    $self->render_later;

    $self->mysql_inet->db->query("INSERT INTO clients \
(create_time, type, guid, login, clients.desc, cn, email, lost) \
VALUES (NOW(), 0, ?, ?, ?, ?, ?, 0)",
      $j->{guid},
      $j->{login},
      $j->{desc} // '',
      $j->{cn},
      $j->{email} // '' =>
      sub {
        my ($db, $err, $results) = @_;
        return $self->render(text => "Database error, inserting client: $err", status => 503) if $err;

        my $last_id = $results->last_insert_id;
        $self->dblog->info("UI: Client id $last_id added successfully");
        $self->render(text => $last_id);
      }
    );

  } else {
    return $self->render(text => 'Unsupported content', status => 503);
  }
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


1;
