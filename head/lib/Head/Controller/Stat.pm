package Head::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub trafstat {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless @$profs;

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j and ref($j) eq 'HASH';

    #$self->log->debug($self->dumper($j));

    if ($self->check_workers) {
      # statistics update is high priority task
      $self->minion->enqueue(traf_stat => [time, $profs, $j] => {priority => 5, attempts => 5});
    } else {
      my $m = 'Statistics not accepted. Execution subsystem error.';
      $self->log->error($m);
      $self->dblog->error($m);
      return $self->render(text=>"Execution subsystem not available", status=>503);
    }

    # successful enqueue
    return $self->render(text=>"DONE ".scalar keys %$j, status=>200);

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


1;
