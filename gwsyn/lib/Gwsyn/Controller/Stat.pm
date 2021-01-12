package Gwsyn::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

sub runstat {
  my $self = shift;

  unless ($self->check_workers) {
    $self->rlog('Error collecting traffic statistics. Execution subsystem error.');
    return $self->render(text=>'Error collecting traffic statistics, execution impossible', status=>503);
  }

  $self->rlog('Initiate traffic statistics collection');
  $self->minion->enqueue('traffic_stat');
  return $self->rendered(200);
}


1;
