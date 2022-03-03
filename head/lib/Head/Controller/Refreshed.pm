package Head::Controller::Refreshed;
use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Mojo::mysql;
use Head::Ural::SyncQueue;


sub refreshed {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text => 'Bad parameter', status => 503) unless @$profs;

  return unless my $j = $self->json_content($self->req);
  my $id = $j->{id};
  my $subsys = $j->{subsys};
  return $self->render(text => 'Bad body parameter', status => 503) unless $id and $subsys;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  $self->syncqueue->remove_flags_p($db, $id, $subsys, $profs)
  ->then(sub {
    my $affected_rows = shift;

    if ($affected_rows == 1) {
      $self->dblog->info("Device id $id $subsys refreshed successfully");
    } elsif ($affected_rows > 1) {
      $self->dblog->info("Device id $id $subsys refreshed, multiple flags are deleted");
    } else {
      $self->dblog->info("Device id $id $subsys refreshed, no flags are deleted");
    }
    $self->rendered(200);

  })->catch(sub {
    my $err = shift;

    my $m = 'Remove sync flags failure';
    $self->log->error("$m: $err");
    $self->dblog->error("$m: $err");
    $self->render(text=>$m, status => 503);
  });
}


1;
