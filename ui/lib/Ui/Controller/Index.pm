package Ui::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

use Ui::Ural::Changelog;

sub index {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  # IMPORTANT!
  # redirect to stat if not admin
  if ($self->stash('remote_user_role') ne 'admin') {
    return $self->redirect_to('stat');
  }

  return undef unless $self->authorize({ admin=>1 });
  return $self->redirect_to('status');
}


sub about {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->aboutstat();
}


sub aboutstat {
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
