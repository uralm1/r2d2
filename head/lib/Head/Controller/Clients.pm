package Head::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use NetAddr::IP::Lite;


sub clients {
  my $self = shift;
  my $prof = $self->stash('profile');
  return $self->render(text=>'Bad parameter', status=>404) unless $prof;

  $self->render_later;
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp \
FROM clients WHERE profile = ? ORDER BY ip ASC", $prof =>
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
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp \
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
  for (qw/id login mac rt defjump speed_in speed_out no_dhcp/) {
    die 'Undefined client record attribute' unless exists $h->{$_};
    $clr->{$_} = $h->{$_};
  }
  return $clr;
}


1;
