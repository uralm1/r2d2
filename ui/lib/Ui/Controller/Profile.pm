package Ui::Controller::Profile;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;


sub newform {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render(text => 'Not implemented');
}


sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render(text => 'Not implemented');
}


1;
