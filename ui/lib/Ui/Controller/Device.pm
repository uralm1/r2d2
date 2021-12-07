package Ui::Controller::Device;
use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Mojo::URL;
use Regexp::Common qw(number net);
use MIME::Base64 qw(decode_base64url);

# new device render form and submit
sub newpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  # client_id parameter is a must
  my $client_id = $v->optional('client_id')->param;
  return unless $self->exists_and_number($client_id);

  my $audit_client_rec = {
    cn => $v->optional('client_cn_a')->param // 'н/д',
    login => $v->optional('client_login_a')->param // 'н/д'
  };

  $self->render_later;

  # render initial form
  return $self->_render_new_device_page($client_id, $audit_client_rec) if keys %{$v->input} <= 3;

  my $j = { }; # resulting json
  $j->{name} = $v->required('name', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $j->{ip} = $v->required('ip', 'not_empty')->like(qr/^$RE{net}{IPv4}$/)->param;
  $j->{mac} = $v->required('mac', 'not_empty')->like(qr/^$RE{net}{MAC}$/)->param;
  $j->{no_dhcp} = $v->optional('no_dhcp')->like(qr/^[01]$/)->param // 0;
  $j->{rt} = $v->required('rt', 'not_empty')->like(qr/^[0-9]$/)->param;
  $j->{defjump} = $v->required('defjump', 'not_empty')->param;
  my $speed_key = $v->required('speed_key', 'not_empty')->param;
  if ($v->is_valid('speed_key') && $speed_key eq 'userdef') {
    $v->required('speed_userdef_in', 'not_empty');
    $v->optional('speed_userdef_out');
  } else {
    $v->optional('speed_userdef_in')->in('');
    $v->optional('speed_userdef_out')->in('');
  }
  $j->{speed_in} = $v->param('speed_userdef_in') // '';
  $j->{speed_out} = $v->param('speed_userdef_out') // '';
  $j->{qs} = $v->required('qs', 'not_empty')->like(qr/^[0-9]$/)->param;
  my $limit_in = $v->required('limit_in', 'not_empty')->like(qr/^$RE{num}{decimal}{-radix=>'[,.]'}{-sep=>'[ ]?'}$/)->param;
  $j->{profile} = $v->required('profile', 'not_empty')->param;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  return $self->_render_new_device_page($client_id, $audit_client_rec) if $v->has_error;

  # retrive speed
  if ($speed_key ne 'userdef') {
    if (my @sp = grep {$_->{key} eq $speed_key} @{$self->config('speed_plans')}) {
      $j->{speed_in} = $sp[0]->{in};
      $j->{speed_out} = $sp[0]->{out};
    }
  } else {
    # userdef, empty speed_out
    $j->{speed_out} = $j->{speed_in} unless $j->{speed_out};
  }
  # improve limit_in a little
  $limit_in =~ s/ //g; # remove separators
  $limit_in =~ s/,/./; # fix comma
  my $audit_limit_in = $limit_in;
  $j->{limit_in} = $self->mbtob($limit_in);

  #$self->log->debug("J: ".$self->dumper($j));

  # post to system
  $self->ua->post(Mojo::URL->new("/ui/device/$client_id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Добавление нового клиентского устройства $j->{name}, местоположение $j->{profile}, $j->{ip}, провайдер ".
$self->rt_resolve($j->{rt}).
', режим квоты '.$self->qs_resolve($j->{qs}).
", лимит $audit_limit_in Мб. Клиент $audit_client_rec->{cn} ($audit_client_rec->{login}).");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clientedit')->query(id => $client_id));
    } # post closure
  );
}


# internal
sub _render_new_device_page {
  my ($self, $client_id, $audit_client_rec) = @_;
  croak 'Must pass client_id, audit_client_rec parameters!' unless defined $client_id && defined $audit_client_rec;

  # we need profiles list
  $self->ua->get(Mojo::URL->new("/ui/profiles")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      my @pa = map { $_ eq 'plk' ? [$v->{$_} => $_, selected => 'selected'] : [$v->{$_} => $_] } sort keys %$v;
      $self->stash(profile_array => \@pa);

      return $self->render(template => 'device/new', client_id => $client_id,
        audit_client_rec => $audit_client_rec);
    } # get closure
  );
}


sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $client_id = $self->param('clientid');
  return unless $self->exists_and_number($client_id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(
        client_id => $client_id,
        device_id => $id,
        rec => $v
      );
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
  my $client_id = $v->optional('clientid')->param;
  return unless $self->exists_and_number($client_id);

  my $audit_client_rec = {
    client_cn => $v->optional('client_cn_a')->param // 'н/д',
    client_login => $v->optional('client_login_a')->param // 'н/д'
  };

  my $j = { id => $id }; # resulting json
  $j->{name} = $v->required('name', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $j->{ip} = $v->required('ip', 'not_empty')->like(qr/^$RE{net}{IPv4}$/)->param;
  $j->{mac} = $v->required('mac', 'not_empty')->like(qr/^$RE{net}{MAC}$/)->param;
  $j->{no_dhcp} = $v->optional('no_dhcp')->like(qr/^[01]$/)->param // 0;
  $j->{rt} = $v->required('rt', 'not_empty')->like(qr/^[0-9]$/)->param;
  $j->{defjump} = $v->required('defjump', 'not_empty')->param;
  my $speed_key = $v->required('speed_key', 'not_empty')->param;
  if ($v->is_valid('speed_key') && $speed_key eq 'userdef') {
    $v->required('speed_userdef_in', 'not_empty');
    $v->optional('speed_userdef_out');
  } else {
    $v->optional('speed_userdef_in')->in('');
    $v->optional('speed_userdef_out')->in('');
  }
  $j->{speed_in} = $v->param('speed_userdef_in') // '';
  $j->{speed_out} = $v->param('speed_userdef_out') // '';
  $j->{qs} = $v->required('qs', 'not_empty')->like(qr/^[0-9]$/)->param;
  my $limit_in = $v->required('limit_in', 'not_empty')->like(qr/^$RE{num}{decimal}{-radix=>'[,.]'}{-sep=>'[ ]?'}$/)->param;
  $j->{profile} = $v->required('profile', 'not_empty')->param;

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  return $self->render(template => 'device/edit',
    client_id => $client_id, device_id => $id, rec => $audit_client_rec) if $v->has_error;

  # retrive speed
  if ($speed_key ne 'userdef') {
    if (my @sp = grep {$_->{key} eq $speed_key} @{$self->config('speed_plans')}) {
      $j->{speed_in} = $sp[0]->{in};
      $j->{speed_out} = $sp[0]->{out};
    }
  } else {
    # userdef, empty speed_out
    $j->{speed_out} = $j->{speed_in} unless $j->{speed_out};
  }
  # improve limit_in a little
  $limit_in =~ s/ //g; # remove separators
  $limit_in =~ s/,/./; # fix comma
  my $audit_limit_in = $limit_in;
  $j->{limit_in} = $self->mbtob($limit_in);

  #$self->log->debug("J: ".$self->dumper($j));

  # post (put) to system
  $self->render_later;

  $self->ua->put(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Редактирование клиентского устройства $j->{name}, местоположение $j->{profile}, $j->{ip}, провайдер ".
$self->rt_resolve($j->{rt}).
', режим квоты '.$self->qs_resolve($j->{qs}).
", лимит $audit_limit_in Мб. Клиент $audit_client_rec->{client_cn} ($audit_client_rec->{client_login}).");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clientedit')->query(id => $client_id));
    } # put closure
  );
}


sub move {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $client_id = $self->param('clientid');
  return unless $self->exists_and_number($client_id);

  my $search = $self->param('s') // '';

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      if ($search ne '') {
        # perform search
        $self->ua->get(Mojo::URL->new("/ui/search/0")->to_abs($self->head_url)->
          query({s => $search, limit => 5}) =>
          {Accept => 'application/json'} =>
          sub {
            my ($ua, $tx1) = @_;
            my $res1 = eval { $tx1->result };
            return unless $self->request_success($res1);
            return unless my $res_tab = $self->request_json($res1);

            $self->render(template => 'device/move',
              client_id => $client_id,
              device_id => $id,
              rec => $v,
              res_tab => $res_tab,
              search => $search,
            );
          } # search closure
        );
      } else {
        #$search = ''; # already done
        $self->render(template => 'device/move',
          client_id => $client_id,
          device_id => $id,
          rec => $v,
          res_tab => undef,
          search => '',
        );
      }

    } # get device closure
  );
}


sub movepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  $self->render_later;

  my $device_id = $v->optional('id')->param;
  return unless $self->exists_and_number($device_id);
  my $old_client_id = $v->optional('clientid')->param;
  return unless $self->exists_and_number($old_client_id);

  my $audit_name = $v->optional('name_a')->param // 'н/д';
  my $audit_ip = $v->optional('ip_a')->param // 'н/д';
  my $audit_profile = $v->optional('profile_a')->param // 'н/д';
  my $audit_oldclient_cn = $v->optional('oldclient_cn_a')->param // 'н/д';
  my $audit_oldclient_login = $v->optional('oldclient_login_a')->param // 'н/д';
  my $audit_client_cn = $v->optional('client_cn_a')->param // 'н/д';
  my $audit_client_login = $v->optional('client_login_a')->param // 'н/д';

  my $search = $v->optional('s')->param || '';
  my $back_url = defined $v->optional('back')->param ?
    $self->url_for('devicemove')->query(id => $device_id, clientid => $old_client_id, s => $search, back => 1) :
    $self->url_for('devicemove')->query(id => $device_id, clientid => $old_client_id, s => $search);

  my $sel_id = $v->required('ucid')->param;
  if ($v->is_valid) { # check ucid
    $sel_id = decode_base64url($sel_id);
    return unless $self->exists_and_number($sel_id);

    if ($sel_id == $old_client_id) {
      $self->flash(oper => 'Ошибка. Устройство уже принадлежит данному клиенту.');
      return $self->redirect_to($back_url);
    }

    my $j = { id => $old_client_id, newid => $sel_id }; # patch request body json

    # post (patch) to system
    $self->ua->patch(Mojo::URL->new("/ui/device/move/$old_client_id/$device_id")->to_abs($self->head_url) => json => $j =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return unless $self->request_success($res);

        $self->raudit("Перенос клиентского устройства $audit_name, местоположение $audit_profile, $audit_ip \
от клиента $audit_oldclient_cn ($audit_oldclient_login) новому клиенту $audit_client_cn ($audit_client_login).");

        # do redirect with a toast
        $self->flash(oper => 'Устройство перенесено новому клиенту.');
        return $self->redirect_to('/clients');
      } # patch closure
    );

  } else {
    $self->flash(oper => 'Ошибка. Не выбран клиент.');
    $self->redirect_to($back_url);
  }
}


sub delete {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $client_id = $self->param('clientid');
  return unless $self->exists_and_number($client_id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(client_id => $client_id, device_id => $id, rec => $v);
    } # get closure
  );
}


sub deletepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);
  my $client_id = $v->optional('clientid')->param;
  return unless $self->exists_and_number($client_id);

  my $audit_name = $v->optional('name_a')->param // 'н/д';
  my $audit_ip = $v->optional('ip_a')->param // 'н/д';
  my $audit_profile = $v->optional('profile_a')->param // 'н/д';
  my $audit_client_cn = $v->optional('client_cn_a')->param // 'н/д';
  my $audit_client_login = $v->optional('client_login_a')->param // 'н/д';

  # send (delete) to system
  $self->render_later;

  $self->ua->delete(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      $self->raudit("Удаление клиентского устройства $audit_name, местоположение $audit_profile, $audit_ip. Клиент $audit_client_cn ($audit_client_login).");

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clientedit')->query(id => $client_id));
    } # delete closure
  );
}


sub limit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);
  my $client_id = $self->param('clientid');
  return unless $self->exists_and_number($client_id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/device/$client_id/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(client_id => $client_id, device_id => $id, rec => $v);
    } # get closure
  );
}


sub limitpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;
  $self->log->debug("I: ".$self->dumper($v->input));

  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);
  my $client_id = $v->optional('clientid')->param;
  return unless $self->exists_and_number($client_id);

  my $audit_client_rec = {
    client_cn => $v->optional('client_cn_a')->param // 'н/д',
    client_login => $v->optional('client_login_a')->param // 'н/д'
  };

  my $j = { }; # patch request body json
  $j->{qs} = $v->required('qs', 'not_empty')->like(qr/^[0-9]$/)->param;
  my $limit_in = $v->required('limit_in', 'not_empty')->like(qr/^$RE{num}{decimal}{-radix=>'[,.]'}{-sep=>'[ ]?'}$/)->param;
  $j->{reset_sum} = $v->optional('reset_sum')->like(qr/^[01]$/)->param // 0;
  $j->{add_sum} = $v->optional('add_sum')->like(qr/^[01]$/)->param // 0;

  my $audit_name = $v->optional('name')->param // 'н/д';
  my $audit_ip = $v->optional('ip')->param // 'н/д';
  my $audit_profile = $v->optional('profile')->param // 'н/д';

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  return $self->render(template => 'device/limit',
    client_id => $client_id, device_id => $id, rec => $audit_client_rec) if $v->has_error;

  # improve limit_in a little
  $limit_in =~ s/ //g; # remove separators
  $limit_in =~ s/,/./; # fix comma
  my $audit_limit_in = $limit_in;
  $j->{limit_in} = $self->mbtob($limit_in);

  $self->log->debug("J: ".$self->dumper($j));

  # post (patch) to system
  $self->render_later;

  $self->ua->patch(Mojo::URL->new("/ui/device/limit/$client_id/$id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      my $tl = $j->{add_sum} ? 'Временное добавление' : 'Изменение';
      my $tl1 = $j->{reset_sum} ? 'Счетчик трафика сброшен. ' : '';
      $self->raudit("${tl} лимита клиентского устройства $audit_name, местоположение $audit_profile, $audit_ip".
", объем $audit_limit_in Мб, режим квоты ".$self->qs_resolve($j->{qs}).
". ${tl1}Клиент $audit_client_rec->{client_cn} ($audit_client_rec->{client_login}).");

      # do redirect with flash
      $self->flash(oper => 'Лимит устройства изменен.');
      $self->redirect_to($self->url_for('clientedit')->query(id => $client_id));
    } # patch closure
  );
}


sub stat {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $device_id = $self->param('id');
  return unless $self->exists_and_number($device_id);
  my $client_id = $self->param('clientid');
  return unless $self->exists_and_number($client_id);
  my $reptype = $self->param('rep') // '';
  my $activetab;
  my $q = '';
  if ($reptype eq 'month') {
    $activetab = 3;
    $q = '?rep=month';
  } else {
    $activetab = 2;
  }

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/stat/device/$client_id/$device_id$q")
    ->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(
        client_id => $client_id,
        device_id => $device_id,
        rec => $v,
        rep => $reptype,
        activetab => $activetab
      );
    } # get closure
  );
}


1;
