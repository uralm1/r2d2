package Head::Controller::UiDevices;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use NetAddr::IP::Lite;


# new client device submit
sub devicepost {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return unless $self->json_validate($j, 'client_device_record');

    return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

    my $ipo = NetAddr::IP::Lite->new($j->{ip});
    return $self->render(text=>'Bad ip', status => 503) unless $ipo;

    $self->log->debug($self->dumper($j));
    $self->render_later;

    $self->mysql_inet->db->query("SELECT id FROM clients WHERE id = ? AND type = 0",
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
  } else {
    return $self->render(text => 'Unsupported content', status => 503);
  }
}


1;
