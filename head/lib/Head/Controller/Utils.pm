package Head::Controller::Utils;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use Mojo::URL;
use Mojo::Promise;

sub subsys {
  my $self = shift;
  if ($self->accepts('json')) {
    $self->render_later;

    my $db = $self->build_db_info($self->config('inet_db_conn'));
    my $db_minion = $self->build_db_info($self->config('minion_db_conn'));
    my $j = {
      subsys => $self->stash('subsys'),
      version => $self->stash('version'),
      db => $db,
      'db-minion' => $db_minion
    };
    Mojo::Promise->all($db->{status}, $db_minion->{status})
    ->then(sub {
      my ($st1, $st2) = @_;
      $db->{status} = $st1->[0]->array->[1];
      $db_minion->{status} = $st2->[0]->array->[1];
      $self->render(json => $j);
    })->catch(sub {
      my $err = shift;
      $db->{status} = 'нет ответа';
      $db_minion->{status} = 'нет ответа';
      $self->render(json => $j);
    });

  } else {
    $self->render(text => $self->stash('subsys').' ('.$self->stash('version').')');
  }
}


# { database_info_object_hash } = $self->build_db_info('mysql://user:pass@srv/inet'));
sub build_db_info {
  my ($self, $connstr) = @_;
  my $u = Mojo::URL->new($connstr);
  my $dbo = Mojo::mysql->new($connstr);
  return {
    name => $u->path->parts->[0],
    hostport => $u->host_port,
    scheme => $u->scheme,
    state => $dbo->db->ping ? 1 : 0,
    status => $dbo->db->query_p("SHOW VARIABLES LIKE 'version'"),
  };
}


1;
