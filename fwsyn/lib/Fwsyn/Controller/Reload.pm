package Fwsyn::Controller::Reload;
use Mojo::Base 'Mojolicious::Controller';


sub reload {
  my $self = shift;

  unless ($self->check_workers) {
    $self->rlog('Error reloading clients. Execution subsystem error.');
    return $self->render(text=>'Error reloading clients, execution impossible', status=>503);
  }

  $self->minion->enqueue('load_clients');
  return $self->rendered(200);
}


1;
