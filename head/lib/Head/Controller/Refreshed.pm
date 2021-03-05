package Head::Controller::Refreshed;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub refreshed {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless(@$profs);

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j;
    my $id = $j->{id};
    my $subsys = $j->{subsys};
    return $self->render(text=>'Bad body parameter', status=>503) unless($id and $subsys);

    $self->render_later;

    my $e = eval { $self->update_db_flags($profs, $id, $subsys) };
    unless ($e) {
      $self->log->error("Database start update failure $@");
      return $self->render(text=>"Database start update failure", status=>503);
    }

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


# $self->update_db_flags($profs, $id, $subsys)
sub update_db_flags {
  my ($self, $profs, $id, $subsys) = @_;
  croak 'Bad arguments' unless ($profs and $id and $subsys);

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

    if ($results->affected_rows > 0) {
      $self->dblog->info("Client id $id $subsys refreshed successfully");
    } else {
      $self->dblog->info("Client id $id $subsys refreshed but nothing is updated");
    }
    $self->rendered(200);
  };

  my $db = $self->mysql_inet->db;
  my $rule = '';
  for (@$profs) {
    if ($rule eq '') { # first
      $rule = 'profile IN ('.$db->quote($_);
    } else { # second etc
      $rule .= ','.$db->quote($_);
    }
  }
  $rule .= ') AND' if $rule ne '';
  #$self->log->debug("WHERE rule: *$rule*");

  # start database operation that continue in callback
  # RTSYN
  if ($agent_type eq 'rtsyn') {
    $db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = 0 WHERE $rule clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  # DHCPSYN
  } elsif ($agent_type eq 'dhcpsyn') {
    # this is BAD WORKAROUND to ensure compatibility bitween old flags scheme
    # and multiple agents of the same type in one profile
    if ($subsys =~ /\@plksrv1$/i) {
      $db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = s.sync_dhcp & 2 WHERE $rule clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    } elsif ($subsys =~ /\@plksrv4$/i) {
      $db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = s.sync_dhcp & 1 WHERE $rule clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    } else {
      # UNKNOWN? issue warning
      $self->dblog->info("Client id $id dhcpsyn unknown subsys $subsys. Check this.");
      $db->query("UPDATE clients, clients_sync s \
SET s.sync_dhcp = 0 WHERE $rule clients.id = ? AND clients.login = s.login", $id
        => $_cb
      );
    }

  # FWSYN
  } elsif ($agent_type eq 'fwsyn') {
    $db->query("UPDATE clients, clients_sync s \
SET s.sync_fw = 0 WHERE $rule clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  # GWSYN
  } elsif ($agent_type eq 'gwsyn') {
    $db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = 0, s.sync_dhcp = 0, s.sync_fw = 0 WHERE $rule clients.id = ? AND clients.login = s.login", $id
      => $_cb
    );

  } else {
    die "client id $id, unsupported agent $subsys";
  }
  # end if switch by agent_type
}


1;
