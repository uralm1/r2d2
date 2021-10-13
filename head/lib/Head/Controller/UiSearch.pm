package Head::Controller::UiSearch;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;

sub searchclient {
  my $self = shift;

  my $search = $self->param('s');
  my $limit = $self->param('limit') // 5;
  return $self->render(text => 'Bad parameter format', status => 400)
    unless defined $search && $limit =~ /^\d+$/;
  return $self->render(text => 'Max 100 results', status => 400) if $limit > 100;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  my @apnd;
  if ($search ne '') {
    push @apnd, 'cn LIKE '.$db->quote("$search%");
    push @apnd, 'login LIKE '.$db->quote("$search%");
  }
  my $apnd = join ' OR ', @apnd;
  $apnd = (defined $apnd && $apnd ne '') ? " AND ($apnd)" : '';
  #say $apnd;

  $db->query("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, cn, email \
FROM clients c \
WHERE type = 0 $apnd \
ORDER BY id ASC LIMIT ?",
    $limit =>
    sub {
      my ($db, $err, $results) = @_;
      $self->render(text => "Database error, searching clients: $err", status => 503) if $err;

      my $cl = undef;
      if (my $d = $results->hashes) {
        $cl = $d->map(sub { eval { Head::Controller::UiClients::_build_client_rec($_) } })->compact;
        return $self->render(text => 'Client attribute error', status => 503) unless $cl;
      } else {
        return $self->render(text => 'Database error, bad result', status => 503);
      }

      $self->render(json => $cl);
    }
  );
}


sub searchclientbylogin {
  my $self = shift;

  my $login = $self->param('login');
  return $self->render(text => 'Bad parameter format', status => 400)
    unless defined $login;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  $db->query("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, cn, email \
FROM clients c \
WHERE type = 0 AND login = ? LIMIT 1",
    $login =>
    sub {
      my ($db, $err, $results) = @_;
      $self->render(text => "Database error, searching clients: $err", status => 503) if $err;

      if (my $rh = $results->hash) {
        my $cl = eval { Head::Controller::UiClients::_build_client_rec($rh) };
        return $self->render(text => 'Client attribute error', status => 503) unless $cl;

        $self->render(json => $cl);

      } else {
        return $self->render(text => 'Not found', status => 404);
      }
    }
  );
}


1;
