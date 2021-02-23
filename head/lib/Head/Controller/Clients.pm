package Head::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use NetAddr::IP::Lite;
use Carp;

sub clients {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  my $rule = '';
  for (@$profs) {
    if ($rule eq '') { # first
      $rule = 'WHERE profile IN ('.$db->quote($_);
    } else { # second etc
      $rule .= ','.$db->quote($_);
    }
  }
  $rule .= ')' if $rule ne '';
  #$self->log->debug("WHERE rule: *$rule*");

  $db->query("SELECT id, login, clients.desc, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, profile \
FROM clients $rule ORDER BY id ASC" =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rc = $results->hashes) {
        $self->render(json => $rc->map(sub {
          return eval { _build_client_rec($_) };
        })->compact);
      } else {
        return $self->render(text=>'Not found', status=>404);
      }
    }
  );
}


# DEPRECATED
sub clients_old {
  my $self = shift;
  my $prof = $self->stash('profile');
  return $self->render(text=>'Bad parameter', status=>503) unless $prof;

  $self->render_later;
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, profile \
FROM clients WHERE profile = ? ORDER BY id ASC", $prof =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rc = $results->hashes) {
        $self->render(json => $rc->map(sub {
          return eval { _build_client_rec($_) };
        })->compact);
      } else {
        return $self->render(text=>'Not found', status=>404);
      }
    }
  );
}


sub client {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status=>404) unless (defined($id) && $id =~ /^\d+$/);

  $self->render_later;
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, profile \
FROM clients WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rh = $results->hash) {
        my $clr = eval { _build_client_rec($rh) };
        return $self->render(text=>'Invalid IP', status=>503) unless $clr;
        $self->render(json => $clr);
      } else {
        return $self->render(text=>'Not found', status=>404);
      }
    }
  );
}


# { client_rec_hash } = eval { _build_client_rec( { hash_from_database } ) };
sub _build_client_rec {
  my $h = shift;
  my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP adress failure';
  my $clr = { ip => $ipo->addr };
  for (qw/id login mac rt defjump speed_in speed_out no_dhcp profile/) {
    die 'Undefined client record attribute' unless exists $h->{$_};
    $clr->{$_} = $h->{$_};
  }
  return $clr;
}


1;
