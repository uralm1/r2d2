package Ui::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render;
}


sub about {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  $self->render;
}


1;
