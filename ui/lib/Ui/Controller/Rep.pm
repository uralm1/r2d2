package Ui::Controller::Rep;
use Mojo::Base 'Mojolicious::Controller';

sub client {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);



  $self->render(id => $id);
}


1;
