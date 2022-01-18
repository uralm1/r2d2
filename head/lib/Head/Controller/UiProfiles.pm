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
    my $err = $self->handle_profiles(@_);
    Mojo::Promise->reject($err) if $err;

  })->then(sub {
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


# $all_db_promise = $self->profiles_p($db)
sub profiles_p {
  my ($self, $db) = @_;
  my $lines_on_page = $self->stash('lines_on_page');

  my $count_p = $db->query_p('SELECT COUNT(*) FROM profiles');

  my $profiles_p = $db->query_p("SELECT id, profile AS `key`, name, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck FROM profiles \
ORDER BY profile, id LIMIT ? OFFSET ?",
    $lines_on_page,
    ($self->stash('page') - 1) * $lines_on_page
  );

  my $agents_p = $db->query_p("SELECT id, profile_id, name, type, url, block, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck, state, status \
FROM profiles_agents ORDER BY id");

  # return compound promise
  Mojo::Promise->all($count_p, $profiles_p, $agents_p);
}


# ''|'error string' = $self->handle_profiles($all_db_promise_resolve)
sub handle_profiles {
  my ($self, $count_p, $profiles_p, $agents_p) = @_;

  my $j = $self->stash('j');
  my $page = $self->stash('page');
  my $lines_on_page = $self->stash('lines_on_page');

  my $lines_total = $count_p->[0]->array->[0];
  my $num_pages = ceil($lines_total / $lines_on_page);
  return 'Bad parameter value' if $page < 1 || ($num_pages > 0 && $page > $num_pages);

  $self->stash(lines_total => $lines_total, num_pages => $num_pages);

  # reconcile agents
  my %_ah;
  while (my $next = $agents_p->[0]->hash) {
    my $ag = eval { _build_agent_rec($next) };
    return 'Profile attribute error (agent)' unless $ag;
    push @{$_ah{ $next->{profile_id} }}, $ag;
  }

  while (my $next = $profiles_p->[0]->hash) {
    my $pr = eval { _build_profile_rec($next) };
    return 'Profile attribute error' unless $pr;

    $pr->{agents} = $_ah{ $next->{id} } // [];
    push @$j, $pr;
  }

  # success
  return '';
}


# { profile_rec_hash } = _build_profile_rec( { hash_from_database } );
sub _build_profile_rec {
  my $h = shift;
  my $r = {};
  for (qw/key name/) {
    die 'Undefined profile record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  $r->{lastcheck} = $h->{lastcheck} // '';
  return $r;
}


# { agent_rec_hash } = _build_agent_rec( { hash_from_database } );
sub _build_agent_rec {
  my $h = shift;
  my $r = {};
  for (qw/name type url block state status/) {
    die 'Undefined agent record attribute' unless exists $h->{$_};
    $r->{$_} = $h->{$_};
  }
  $r->{lastcheck} = $h->{lastcheck} // '';
  return $r;
}



# new profile submit
sub profilepost {
  my $self = shift;
  return unless my $j = $self->json_content($self->req);
  return unless $self->json_validate($j, 'profile_record');

  #return $self->render(text => 'Bad id', status => 503) if exists $j->{id};

  $self->log->debug($self->dumper($j));
  $self->render_later;

  $self->mysql_inet->db->query("INSERT INTO profiles \
(profile, name) VALUES (?, ?)",
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


1;
