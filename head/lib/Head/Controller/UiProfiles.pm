package Head::Controller::UiProfiles;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::Promise;
use Mojo::mysql;
use POSIX qw(ceil);

sub list {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;
  $self->stash(page => $page, lines_on_page => $lines_on_page);

  $self->render_later;

  my $db = $self->mysql_inet->db;

  $self->stash(j => []); # resulting d attribute

  $self->profiles_p($db)
  ->then(sub {
    my $j = $self->stash('j');
    #say $self->dumper($j);
    $self->render(json => {
      d => $j,
      lines_total => $self->stash('lines_total'),
      pages => $self->stash('num_pages'),
      page => $page,
      lines_on_page => $lines_on_page
    });

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad parameter value/i) {
      $self->render(text => $err, status => 400);
    } elsif ($err =~ /^profile attribute error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => "Database error: $err", status => 503);
    }
  });
}


# $promise = $self->profiles_p($db)
#
# $self->profiles_p($db)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub profiles_p {
  my ($self, $db) = @_;
  my $lines_on_page = $self->stash('lines_on_page');

  my $count_p = $db->query_p('SELECT COUNT(*) FROM profiles');

  my $profiles_p = $db->query_p("SELECT id, profile, name FROM profiles \
ORDER BY profile, id LIMIT ? OFFSET ?",
    $lines_on_page,
    ($self->stash('page') - 1) * $lines_on_page
  );

  my $agents_p = $db->query_p("SELECT id, profile_id, name, type, url, block \
FROM profiles_agents ORDER BY id");

  # return compound promise
  Mojo::Promise->all($count_p, $profiles_p, $agents_p)
  ->then(sub {
    my ($count_p, $profiles_p, $agents_p) = @_;

    my $j = $self->stash('j');
    my $page = $self->stash('page');
    my $lines_on_page = $self->stash('lines_on_page');

    my $lines_total = $count_p->[0]->array->[0];
    my $num_pages = ceil($lines_total / $lines_on_page);
    return Mojo::Promise->reject('Bad parameter value') if $page < 1 || ($num_pages > 0 && $page > $num_pages);

    $self->stash(lines_total => $lines_total, num_pages => $num_pages);

    # reconcile agents
    my %_ah;
    while (my $next = $agents_p->[0]->hash) {
      my $ag = eval { Head::Controller::UiAgents::_build_agent_rec($next) };
      return Mojo::Promise->reject('Profile attribute error (agent)') unless $ag;
      push @{$_ah{ $next->{profile_id} }}, $ag;
    }

    while (my $next = $profiles_p->[0]->hash) {
      my $pr = eval { _build_profile_rec($next) };
      return Mojo::Promise->reject('Profile attribute error') unless $pr;

      $pr->{agents} = $_ah{ $next->{id} } // [];
      push @$j, $pr;
    }

    # success
    return Mojo::Promise->resolve(1);
  });
}


# { profile_rec_hash } = _build_profile_rec( { hash_from_database } );
sub _build_profile_rec {
  my $h = shift;
  my $r = {};
  for (qw/id profile name/) {
    die 'Undefined profile record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  return $r;
}



sub profileget {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text => 'Bad parameter', status => 404) unless defined $id && $id =~ /^\d+$/;

  $self->render_later;

  $self->mysql_inet->db->query("SELECT id, profile, name \
FROM profiles WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, retrieving profile: $err", status => 503) if $err;

      if (my $next = $results->hash) {
        my $pr = eval { _build_profile_rec($next) };
        return $self->render(text => 'Profile attribute error', status => 503) unless $pr;
        $results->finish;

        $db->query("SELECT a.id, a.name, a.type, a.url, a.block, p.profile, p.name AS profile_name \
FROM profiles_agents a INNER JOIN profiles p ON a.profile_id = p.id \
WHERE a.profile_id = ? ORDER BY a.id ASC LIMIT 100", $pr->{id} =>
          sub {
            my ($db, $err, $results) = @_;
            return $self->render(text => "Database error, retrieving profile agents: $err", status => 503) if $err;

            my $agents = undef;
            if (my $a = $results->hashes) {
              $agents = $a->map(sub { return eval { Head::Controller::UiAgents::_build_agent_rec($_) } })->compact;
            } else {
              return $self->render(text => 'Database error, bad result', status => 503);
            }

            $pr->{agents} = $agents;

            $self->render(json => $pr);
          }
        ); # inner query
      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  ); # outer query
}


# new profile submit
sub profilepost {
  my $self = shift;
  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'profile_record');

  return $self->render(text => 'Bad id', status => 503) if exists $j->{id};

  $self->log->debug($self->dumper($j));
  $self->render_later;

  $self->mysql_inet->db->query("INSERT INTO profiles (profile, name) VALUES (?, ?)",
    $j->{profile},
    $j->{name} =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, inserting profile: $err", status => 503) if $err;

      my $last_id = $results->last_insert_id;
      $self->dblog->info("UI: Profile id $last_id added successfully");
      # FIXME update local profile hash!
      $self->render(text => $last_id);
    }
  );
}


# edit profile submit
sub profileput {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'profile_record');

  $self->log->debug($self->dumper($j));
  return $self->render(text => 'Bad id', status => 503) if exists $j->{id} && $j->{id} != $id;

  $self->render_later;

  $self->mysql_inet->db->query("UPDATE profiles \
SET profile = ?, name = ? \
WHERE id = ?",
    $j->{profile},
    $j->{name},
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, updating profile: $err", status => 503) if $err;

      if ($results->affected_rows > 0) {
        $self->dblog->info("UI: Profile id $id updated successfully");
        # FIXME update local profile hash!
        $self->rendered(200);
      } else {
        $self->dblog->info("UI: Profile id $id not updated");
        $self->render(text => "Profile id $id not found", status => 404);
      }
    }
  ); # outer query
}


# delete profile submit
sub profiledelete {
  my $self = shift;
  my $id = $self->stash('id');
  return unless $self->exists_and_number404($id);

  #$self->log->debug("Deleting id: $id");

  $self->render_later;

  $self->mysql_inet->db->query("SELECT id FROM profiles_agents WHERE profile_id = ?",
    $id =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, checking profile agents: $err", status => 503) if $err;
      return $self->render(text => 'Refused, profile agents exist', status => 400) if $results->rows > 0;

      $results->finish;

      $db->query("DELETE FROM profiles WHERE id = ?", $id =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => "Database error, deleting profile: $err", status => 503) if $err;

          if ($results->affected_rows > 0) {
            $self->dblog->info("UI: Profile id $id deleted successfully");
            # FIXME update local profile hash!
            $self->rendered(200);
          } else {
            $self->dblog->info("UI: Profile id $id not deleted");
            $self->render(text => "Profile id $id not found", status => 404);
          }
        }
      ); # inner query
    }
  ); # outer query
}


1;
