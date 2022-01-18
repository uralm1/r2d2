package Ui::Controller::Profile;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;


sub newform {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render_later;

  $self->_render_new_profile_page;
}


sub newpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text => 'Не дал показания') unless $v->has_data;

  my $j = { }; # resulting json
  $j->{profile} = $v->required('profile', 'not_empty')->like(qr/^[A-Za-z_][A-Za-z0-9_\.\-]*$/)->param;
  $j->{name} = $v->required('name', 'not_empty')->param;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  $self->render_later;

  # rerender page with error
  return $self->_render_new_profile_page if $v->has_error;

  $self->log->debug($self->dumper($j));

  # post to system
  $self->ua->post(Mojo::URL->new('/ui/profile')->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Создание нового профиля $j->{profile} объекта $j->{name}.");

      # do redirect with a toast
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profiles'));
    } # post closure
  );
}


# internal
sub _render_new_profile_page {
  shift->render(template => 'profile/new');
}


sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render(text => 'Not implemented');
}


1;
