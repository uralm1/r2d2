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

      $self->raudit("Создание нового профиля $j->{profile} объект $j->{name}.");

      # do redirect with a toast
      $self->flash(oper => 'Выполнено успешно.');
      my $last_id = $res->body;
      if ($last_id =~ /^\d+$/) {
        $self->redirect_to($self->url_for('profileedit')->query(id => $last_id));
      } else {
        $self->redirect_to($self->url_for('profiles'));
      }
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

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/profile/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(profile_id => $id, rec => $v);
    } # get closure
  );
}


sub editpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);

  my $j = { id => $id }; # resulting json
  $j->{profile} = $v->required('profile', 'not_empty')->like(qr/^[A-Za-z_][A-Za-z0-9_\.\-]*$/)->param;
  $j->{name} = $v->required('name', 'not_empty')->param;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  $self->render_later;

  # rerender page with errors
  if ($v->has_error) {
    # reget $rec back
    $self->ua->get(Mojo::URL->new("/ui/profile/$id")->to_abs($self->head_url) =>
      {Accept => 'application/json'} =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return unless $self->request_success($res);
        return unless my $vv = $self->request_json($res);

        return $self->render(template => 'profile/edit', profile_id => $id, rec => $vv);
      } # get closure
    );
    return undef;
  }

  #$self->log->debug("J: ".$self->dumper($j));

  # post (put) to system
  $self->ua->put(Mojo::URL->new("/ui/profile/$id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Редактирование профиля $j->{profile} объект $j->{name}.");

      # do redirect with a toast
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profiles'));
    } # post closure
  );
}


sub delete {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/profile/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(profile_id => $id, rec => $v);
    } # get closure
  );
}


sub deletepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);

  my $audit_profile = $v->optional('profile_a')->param // 'н/д';
  my $audit_name = $v->optional('name_a')->param // 'н/д';

  # send (delete) to system
  $self->render_later;

  $self->ua->delete(Mojo::URL->new("/ui/profile/$id")->to_abs($self->head_url) =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Удаление профиля $audit_profile объект $audit_name.");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profiles'));
    } # delete closure
  );
}


1;
