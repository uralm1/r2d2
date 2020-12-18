package Head::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use NetAddr::IP::Lite;


sub clients {
  my $self = shift;
  my $pid = $self->stash('id');
  return $self->render(text=>'Bad parameter', status=>404) unless (defined($pid) && $pid =~ /^\d+$/);

  $self->render_later;
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, no_dhcp \
FROM clients WHERE profile_id = ? ORDER BY ip ASC", $pid =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rc = $results->hashes) {
        $self->render(json => $rc->map(sub {
          my $ipo = NetAddr::IP::Lite->new($_->{ip});
          return undef unless $ipo;
          { id => $_->{id},
            login => $_->{login},
            ip => $ipo->addr,
            mac => $_->{mac},
            rt => $_->{rt},
            no_dhcp => $_->{no_dhcp},
          }
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
  $self->mysql_inet->db->query("SELECT id, login, clients.desc, ip, mac, rt, no_dhcp \
FROM clients WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rh = $results->hash) {
        my $ipo = NetAddr::IP::Lite->new($rh->{ip});
        return $self->render(text=>'Invalid IP', status=>503) unless $ipo;

        $self->render(json => {
          id => $rh->{id},
          login => $rh->{login},
          ip => $ipo->addr,
          mac => $rh->{mac},
          rt => $rh->{rt},
          no_dhcp => $rh->{no_dhcp},
        });
      } else {
        return $self->render(text=>'Not found', status=>404);
      }
    }
  );
}


1;
