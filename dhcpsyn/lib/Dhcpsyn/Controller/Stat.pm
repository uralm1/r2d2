package Dhcpsyn::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

sub runstat {
  my $self = shift;

  return $self->rendered(501); # Not implemented
}


1;
