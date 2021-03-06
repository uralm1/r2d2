package Ui::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use Ui::Ural::Changelog;

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  # TODO

  $self->render;
}


sub about {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  my $hist;
  if (my $changelog = Ui::Ural::Changelog->new($self->stash('version'), 50)) {
    $hist = $changelog->get_changelog;
  } else {
    $hist = 'Информация отсутствует.';
  }

  $self->render(
    hist => $hist,
  );
}


1;
