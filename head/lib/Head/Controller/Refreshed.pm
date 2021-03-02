package Head::Controller::Refreshed;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub refreshed {
  my $self = shift;

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j;
    my $id = $j->{id};
    my $subsys = $j->{subsys};
    return $self->render(text=>'Bad parameter', status=>503) unless($id and $subsys);

    $self->render_later;

    my $e = eval { $self->update_db_flags($id, $subsys) };
    unless ($e) {
      $self->log->error("Database start update failure $@");
      return $self->render(text=>"Database start update failure", status=>503);
    }

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


# $self->update_db_flags($id, $subsys)
sub update_db_flags {
  my ($self, $id, $subsys) = @_;
  croak 'Bad arguments' unless ($id and $subsys);

  my ($agent_type) = ($subsys =~ /^([^@]+)/);
  die "client id $id bad subsys parameter $subsys" unless $agent_type;

  # define callback
  my $_cb = sub {
    my ($db, $err, $results) = @_;
    if ($err) {
      my $m = "Database flags update failed for client id $id";
      $self->log->error("$m: $err");
      $self->dblog->error($m);
      return $self->render(text=>"Database update failed", status=>503);
    }

    $self->dblog->info("Client id $id $subsys refreshed successfully");
    $self->rendered(200);
  };

  # start database operation that continue in callback
  # RTSYN
  if ($agent_type eq 'rtsyn') {
    $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = 0 WHERE clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  # DHCPSYN
  } elsif ($agent_type eq 'dhcpsyn') {
    # this is BAD WORKAROUND to ensure compatibility bitween old flags scheme
    # and multiple agents of the same type in one profile
    if ($subsys =~ /\@plksrv1$/i) {
      $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = s.sync_dhcp & 2 WHERE clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    } elsif ($subsys =~ /\@plksrv4$/i) {
      $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = s.sync_dhcp & 1 WHERE clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    } else {
      # UNKNOWN? issue warning
      $self->dblog->info("Client id $id dhcpsyn unknown subsys $subsys. Check this.");
      $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = 0 WHERE clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    }

  # FWSYN
  } elsif ($agent_type eq 'fwsyn') {
    $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_fw = 0 WHERE clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  # GWSYN
  } elsif ($agent_type eq 'gwsyn') {
    $self->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = 0, s.sync_dhcp = 0, s.sync_fw = 0 WHERE clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  } else {
    die "client id $id, unsupported agent $subsys";
  }
  # end if switch by agent_type
}


1;
