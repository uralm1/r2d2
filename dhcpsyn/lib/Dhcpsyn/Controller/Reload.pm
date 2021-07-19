package Dhcpsyn::Controller::Reload;
use Mojo::Base 'Mojolicious::Controller';


sub reload {
  my $self = shift;

  unless ($self->check_workers) {
    $self->rlog('Error reloading devices. Execution subsystem error.');
    return $self->render(text=>'Error reloading devices, execution impossible', status=>503);
  }

  $self->ljq->enqueue('load_devices');
  return $self->rendered(200);
}


1;
