package Dhcpsyn::Controller::Utils;
use Mojo::Base 'Mojolicious::Controller';

sub subsys {
  my $self = shift;
  $self->respond_to(
    json => {json => {
      subsys => $self->stash('subsys'),
      version => $self->stash('version'),
      profile => $self->config('my_profile'),
    }},
    any => {text => $self->stash('subsys').' ('.$self->stash('version').')'},
  );
}


1;
