package Ui::Controller::Agent;
use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Mojo::URL;


sub newpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  # profile_id parameter required
  my $profile_id = $v->optional('profile_id')->param;
  return unless $self->exists_and_number($profile_id);

  my $audit_profile_rec = {
    profile => $v->optional('profile_a')->param // 'н/д',
    name => $v->optional('profile_name_a')->param // 'н/д'
  };

  $self->render_later;

  # render initial form
  return $self->_render_new_agent_page($profile_id, $audit_profile_rec) if keys %{$v->input} <= 3;

  my $j = { }; # resulting json
  $j->{name} = $v->required('name', 'not_empty')->param;
  my $subsys_type = $v->required('subsys-type', 'not_empty')->param;
  my $subsys_hostname = $v->optional('subsys-hostname')->like(qr/^[a-z0-9\-.]*$/i)->param // '';
  $j->{url} = $v->required('url', 'not_empty')->param;
  $j->{block} = $v->optional('block')->like(qr/^[01]$/)->param // 0;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  return $self->_render_new_agent_page($profile_id, $audit_profile_rec) if $v->has_error;

  # build subsys (type) value
  $j->{type} = $subsys_type . ($subsys_hostname ne q{} ? '@'.$subsys_hostname : '');

  #$self->log->debug("J: ".$self->dumper($j));

  # post to system
  $self->ua->post(Mojo::URL->new("/ui/agent/$profile_id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Добавление нового агента $j->{name}, тип $j->{type}, url $j->{url}. ".
($j->{block} ? 'Агент поддерживает блокировку. ' : '').
"Профиль $audit_profile_rec->{profile} объект $audit_profile_rec->{name}.");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profileedit')->query(id => $profile_id));
    } # post closure
  );
}


# internal
sub _render_new_agent_page {
  my ($self, $profile_id, $audit_profile_rec) = @_;
  croak 'Must pass profile_id, audit_profile_rec parameters!' unless defined $profile_id && defined $audit_profile_rec;

  return $self->render(template => 'agent/new', profile_id => $profile_id,
    audit_profile_rec => $audit_profile_rec);
}


sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $profile_id = $self->param('profileid');
  return unless $self->exists_and_number($profile_id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/agent/$profile_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(profile_id => $profile_id, agent_id => $id, rec => $v);
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
  my $profile_id = $v->optional('profileid')->param;
  return unless $self->exists_and_number($profile_id);

  my $audit_profile_rec = {
    profile => $v->optional('profile_a')->param // 'н/д',
    name => $v->optional('profile_name_a')->param // 'н/д'
  };

  my $j = { id => $id }; # resulting json
  $j->{name} = $v->required('name', 'not_empty')->param;
  my $subsys_type = $v->required('subsys-type', 'not_empty')->param;
  my $subsys_hostname = $v->optional('subsys-hostname')->like(qr/^[a-z0-9\-.]*$/i)->param // '';
  $j->{url} = $v->required('url', 'not_empty')->param;
  $j->{block} = $v->optional('block')->like(qr/^[01]$/)->param // 0;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  return $self->render(template => 'agent/edit',
    profile_id => $profile_id, agent_id => $id, rec => $audit_profile_rec) if $v->has_error;

  # build subsys (type) value
  $j->{type} = $subsys_type . ($subsys_hostname ne q{} ? '@'.$subsys_hostname : '');

  #$self->log->debug("J: ".$self->dumper($j));

  # post (put) to system
  $self->render_later;

  $self->ua->put(Mojo::URL->new("/ui/agent/$profile_id/$id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Редактирование агента $j->{name}, тип $j->{type}, url $j->{url}. ".
($j->{block} ? 'Агент поддерживает блокировку. ' : '').
"Профиль $audit_profile_rec->{profile} объект $audit_profile_rec->{name}.");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profileedit')->query(id => $profile_id));
    } # put closure
  );
}


sub delete {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $profile_id = $self->param('profileid');
  return unless $self->exists_and_number($profile_id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/agent/$profile_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(profile_id => $profile_id, agent_id => $id, rec => $v);
    } # get closure
  );
}


sub deletepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);
  my $profile_id = $v->optional('profileid')->param;
  return unless $self->exists_and_number($profile_id);

  my $audit_name = $v->optional('name_a')->param // 'н/д';
  my $audit_type = $v->optional('type_a')->param // 'н/д';
  my $audit_url = $v->optional('url_a')->param // 'н/д';
  my $audit_profile = $v->optional('profile_a')->param // 'н/д';
  my $audit_profile_name = $v->optional('profile_name_a')->param // 'н/д';

  # send (delete) to system
  $self->render_later;

  $self->ua->delete(Mojo::URL->new("/ui/agent/$profile_id/$id")->to_abs($self->head_url) =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Удаление агента $audit_name, тип $audit_type, url $audit_url. Профиль $audit_profile объект $audit_profile_name.");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('profileedit')->query(id => $profile_id));
    } # delete closure
  );
}


1;
