package Head::Controller::UiAgents;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;


sub agentget {
  my $self = shift;
  my $profile_id = $self->stash('profile_id');
  return unless $self->exists_and_number404($profile_id);
  my $agent_id = $self->stash('agent_id');
  return unless $self->exists_and_number404($agent_id);

  $self->render_later;

  $self->mysql_inet->db->query("SELECT a.id, a.name, a.type, a.url, a.block, p.profile, p.name AS profile_name \
FROM profiles_agents a INNER JOIN profiles p ON a.profile_id = p.id \
WHERE a.id = ? AND a.profile_id = ?", $agent_id, $profile_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, retrieving agent', status => 503) if $err;

      if (my $rh = $results->hash) {
        my $dr = eval { _build_agent_rec($rh) };
        return $self->render(text => 'Invalid attibute', status => 503) unless $dr;
        $self->render(json => $dr);
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


# { agent_rec_hash } = _build_agent_rec( { hash_from_database } );
sub _build_agent_rec {
  my $h = shift;
  my $r = {};
  for (qw/id name type url block/) {
    die 'Undefined agent record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  for (qw/profile profile_name/) {
    $r->{$_} = $h->{$_} if defined $h->{$_};
  }
  return $r;
}


# edit agent submit
sub agentput {
  my $self = shift;
  my $profile_id = $self->stash('profile_id');
  return unless $self->exists_and_number404($profile_id);
  my $agent_id = $self->stash('agent_id');
  return unless $self->exists_and_number404($agent_id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'profile_agent_record');

  return $self->render(text=>'Bad id', status => 503) if exists($j->{id}) && $j->{id} != $agent_id;

  $self->log->debug($self->dumper($j));
  $self->render_later;

  $self->mysql_inet->db->query("UPDATE profiles_agents \
SET name = ?, type = ?, url = ?, block = ?, state = 0, status = '' \
WHERE id = ? AND profile_id = ? AND EXISTS (SELECT 1 FROM profiles WHERE profiles.id = ?)",
    $j->{name},
    $j->{type},
    $j->{url},
    $j->{block},
    $agent_id, $profile_id, $profile_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating agent: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        # FIXME: update local profile hash!
        $self->dblog->info("UI: Agent id $agent_id updated successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Agent id $agent_id not updated");
        $self->render(text => "Agent id $agent_id not found or profile invalid", status => 404);
      }
    }
  );
}


# new agent submit
sub agentpost {
  my $self = shift;
  my $profile_id = $self->stash('profile_id');
  return unless $self->exists_and_number404($profile_id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'profile_agent_record');

  return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

  $self->log->debug($self->dumper($j));
  $self->render_later;

  $self->mysql_inet->db->query("SELECT 1 FROM profiles WHERE id = ?",
    $profile_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, searching profile: $err", status => 503) if $err;
      return $self->render(text => 'Profile not found', status => 404) if $results->rows < 1;

      $results->finish;

      $db->query("INSERT INTO profiles_agents \
(name, type, url, block, state, status, profile_id) \
VALUES (?, ?, ?, ?, 0, '', ?)",
        $j->{name},
        $j->{type},
        $j->{url},
        $j->{block},
        $profile_id =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => "Database error, inserting agent: $err", status => 503) if $err;

          my $last_id = $results->last_insert_id;

          # finished
          # FIXME: update local profile hash!
          $self->dblog->info("UI: Agent id $last_id added successfully");
          $self->render(text => $last_id);
        }
      ); # inner query
    }
  ); # outer query
}


# delete agent submit
sub agentdelete {
  my $self = shift;
  my $profile_id = $self->stash('profile_id');
  return unless $self->exists_and_number404($profile_id);
  my $agent_id = $self->stash('agent_id');
  return unless $self->exists_and_number404($agent_id);

  #$self->log->debug("Deleting device id: $agent_id");

  $self->render_later;

  $self->mysql_inet->db->query("DELETE FROM profiles_agents WHERE id = ? AND profile_id = ?",
    $agent_id, $profile_id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, deleting agent: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        # FIXME: update local profile hash!
        $self->dblog->info("UI: Agent id $agent_id deleted successfully");
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Agent id $agent_id not deleted");
        $self->render(text => "Agent id $agent_id not found", status => 404);
      }
    }
  );
}


1;
