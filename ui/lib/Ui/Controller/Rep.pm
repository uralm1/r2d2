package Ui::Controller::Rep;
use Mojo::Base 'Mojolicious::Controller';

sub users {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  $self->render(text => 'Users report page');
}


1;
