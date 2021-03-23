package Dhcpsyn::Controller::Block;
use Mojo::Base 'Mojolicious::Controller';

sub block {
  my $self = shift;
  my $id = $self->stash('id');
  my $qs = $self->stash('qs');
  return $self->render(text=>'Bad parameter', status=>503) unless (defined($id) && $id =~ /^\d+$/ &&
    defined($qs) && $qs =~ /^[023]$/);

  return $self->rendered(501); # Not implemented
}


1;
