package Head::Controller::UiServers;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;
use NetAddr::IP::Lite;

sub servers {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status=>400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status=>400) if $lines_on_page > 100;

  $self->render_later;

  $self->mysql_inet->db->query("SELECT COUNT(*) FROM servers INNER JOIN devices ON devices_id = devices.id" =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, total lines counting', status=>503) if $err;

      my $lines_total = $results->array->[0];
      $results->finish;

      my $num_pages = ceil($lines_total / $lines_on_page);
      return $self->render(text => 'Bad parameter value', status => 400) if $page < 1 ||
        ($num_pages > 0 && $page > $num_pages);

      $db->query("SELECT s.id, name, s.desc, DATE_FORMAT(s.create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
FROM servers s INNER JOIN devices d ON s.devices_id = d.id \
ORDER BY s.id ASC LIMIT ? OFFSET ?",
$lines_on_page, ($page - 1) * $lines_on_page =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => 'Database error, retrieving servers', status => 503) if $err;

          if (my $j = $results->hashes) {
            $self->render(json => {
              d => $j->map(sub {
                return eval { _build_server_rec($_) };
              })->compact,
              lines_total => $lines_total,
              pages => $num_pages,
              page => $page,
              lines_on_page => $lines_on_page
            });
          } else {
            $self->render(text => 'Database error, bad result', status=>503);
          }
        }
      ); # inner query
    }
  ); # outer query
}


sub serverget {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status => 404) unless (defined($id) && $id =~ /^\d+$/);

  $self->render_later;
  $self->mysql_inet->db->query("SELECT s.id, name, s.desc, DATE_FORMAT(s.create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
FROM servers s INNER JOIN devices d ON s.devices_id = d.id \
WHERE s.id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, retrieving server', status => 503) if $err;

      if (my $rh = $results->hash) {
        my $sr = eval { _build_server_rec($rh) };
        return $self->render(text => 'Invalid IP', status => 503) unless $sr;
        $self->render(json => $sr);
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


# { servers_rec_hash } = eval { _build_server_rec( { hash_from_database } )};
sub _build_server_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
  my $sr = { ip => $ipo->addr };
  for (qw/id name desc create_time mac rt defjump speed_in speed_out no_dhcp qs limit_in blocked profile/) {
    die 'Undefined server record attribute' unless exists $h->{$_};
    $sr->{$_} = $h->{$_};
  }
  return $sr;
}


# edit server submit
sub serverput {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return unless $self->json_validate($j, 'server_record');

    return $self->render(text=>'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $id;

    my $ipo = NetAddr::IP::Lite->new($j->{ip});
    return $self->render(text=>'Bad ip', status => 503) unless $ipo;

    $self->log->debug($self->dumper($j));
    $self->render_later;

    $self->mysql_inet->db->query("UPDATE servers s INNER JOIN devices d ON s.devices_id = d.id \
SET name = ?, s.desc = ?, ip = ?, mac = ?, no_dhcp = ?, rt = ?, defjump = ?, speed_in = ?, speed_out = ?, qs = ?, limit_in = ?, email_notify = 0 \
WHERE s.id = ?",
      $j->{name},
      $j->{desc},
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

  } else {
    return $self->render(text=>'Unsupported content', status => 503);
  }
}


# new server submit
sub serverpost {
  my $self = shift;
  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return unless $self->json_validate($j, 'server_record');

    return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

    my $ipo = NetAddr::IP::Lite->new($j->{ip});
    return $self->render(text => 'Bad ip', status => 503) unless $ipo;

    $self->log->debug($self->dumper($j));

    # start transaction
    my $db = $self->mysql_inet->db;
    my $tx = eval { $db->begin };
    return $self->render(text => "Database error, transaction failure: $@", status => 503) unless $tx;

    my $results = eval { $db->query("INSERT INTO devices \
(create_time, ip, mac, no_dhcp, rt, defjump, speed_in, speed_out, qs, limit_in, sum_limit_in, profile, email_notify, notified, blocked, bot) \
VALUES (NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 1)",
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
      $j->{profile})
    };
    return $self->render(text => "Database error, inserting devices: $@", status => 503) unless $results;

    my $last_id = $results->last_insert_id;
    $results = eval { $db->query("INSERT INTO servers \
(name, servers.desc, create_time, devices_id) \
VALUES (?, ?, NOW(), ?)",
      $j->{name},
      $j->{desc},
      $last_id)
    };
    return $self->render(text => "Database error, inserting servers: $@", status => 503) unless $results;

    $last_id = $results->last_insert_id;

    eval { $tx->commit };
    return $self->render(text => "Database error, transaction commit failure: $@", status => 503) if $@;

    # finished
    $self->dblog->info("UI: Server id $last_id added successfully");
    $self->render(text => $last_id);
  } else {
    return $self->render(text => 'Unsupported content', status => 503);
  }
}


# delete server submit
sub serverdelete {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  #$self->log->debug("Deleting id: $id");

  $self->render_later;

  $self->mysql_inet->db->query("DELETE servers, devices FROM servers INNER JOIN devices ON servers.devices_id = devices.id \
WHERE servers.id = ?", $id =>
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
