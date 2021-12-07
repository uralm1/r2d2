package Head::Controller::Utils;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use Mojo::URL;

sub subsys {
  my $self = shift;
  $self->respond_to(
    json => { json => {
        subsys => $self->stash('subsys'),
        version => $self->stash('version'),
        db => $self->build_db_info($self->config('inet_db_conn')),
        'db-minion' => $self->build_db_info($self->config('minion_db_conn'))
      }
    },
    any => { text => $self->stash('subsys').' ('.$self->stash('version').')'},
  );
}


# { database_info_object_hash } = $self->build_db_info('mysql://user:pass@srv/inet'));
sub build_db_info {
  my ($self, $connstr) = @_;
  my $u = Mojo::URL->new($connstr);
  my $dbo = Mojo::mysql->new($connstr);
  return {
    name => $u->path->parts->[0],
    host => $u->host,
    scheme => $u->scheme,
    ping => $dbo->db->ping ? 1 : 0
  };
}


1;
