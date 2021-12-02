package Head::Controller::Refreshed;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub refreshed {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless(@$profs);

  return unless my $j = $self->json_content($self->req);
  my $id = $j->{id};
  my $subsys = $j->{subsys};
  return $self->render(text=>'Bad body parameter', status=>503) unless($id and $subsys);

  $self->render_later;

  my $e = eval { $self->update_db_flags($profs, $id, $subsys) };
  unless ($e) {
    $self->log->error("Database start update failure $@");
    return $self->render(text=>"Database start update failure", status=>503);
  }
}


# $self->update_db_flags($profs, $id, $subsys)
sub update_db_flags {
  my ($self, $profs, $id, $subsys) = @_;
  croak 'Bad arguments' unless ($profs and $id and $subsys);

  my ($agent_type) = ($subsys =~ /^([^@]+)/);
  die "device id $id bad subsys parameter $subsys" unless $agent_type;

  # define callback
  my $_cb = sub {
    my ($db, $err, $results) = @_;
    if ($err) {
      my $m = "Database flags update failed for device id $id";
      $self->log->error("$m: $err");
      $self->dblog->error($m);
      return $self->render(text=>"Database update failed", status=>503);
    }

    if ($results->affected_rows > 0) {
      $self->dblog->info("Device id $id $subsys refreshed successfully");
    } else {
      $self->dblog->info("Device id $id $subsys refreshed but nothing is updated");
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
    $db->query("UPDATE devices \
SET sync_flags = sync_flags & 0b11110111 WHERE $rule id = ?", $id
      => $_cb
    );

  # DHCPSYN
  } elsif ($agent_type eq 'dhcpsyn') {
    # FIXME FIXME
    # this is BAD WORKAROUND to ensure compatibility bitween old flags scheme
    # and multiple agents of the same type in one profile
    if ($subsys =~ /\@plksrv1$/i) {
      $db->query("UPDATE devices \
SET sync_flags = sync_flags & 0b11111110 WHERE $rule id = ?", $id
        => $_cb
      );
    } elsif ($subsys =~ /\@plksrv4$/i) {
      $db->query("UPDATE devices \
SET sync_flags = sync_flags & 0b11111101 WHERE $rule id = ?", $id
        => $_cb
      );
    } else {
      # UNKNOWN? issue warning
      $self->dblog->info("Device id $id dhcpsyn unknown subsys $subsys. Check this.");
      $db->query("UPDATE devices \
SET sync_flags = sync_flags & 0b11111100 WHERE $rule id = ?", $id
        => $_cb
      );
    }

  # FWSYN
  } elsif ($agent_type eq 'fwsyn') {
    $db->query("UPDATE devices \
SET sync_flags = sync_flags & 0b11111011 WHERE $rule id = ?", $id
      => $_cb
    );

  # GWSYN
  } elsif ($agent_type eq 'gwsyn') {
    $db->query("UPDATE devices \
SET sync_flags = 0 WHERE $rule id = ?", $id
      => $_cb
    );

  } else {
    die "device id $id, unsupported agent $subsys";
  }
  # end if switch by agent_type
}


1;
