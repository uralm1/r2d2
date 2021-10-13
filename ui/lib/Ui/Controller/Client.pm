package Ui::Controller::Client;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Net::LDAP qw(LDAP_SUCCESS LDAP_INSUFFICIENT_ACCESS LDAP_NO_SUCH_OBJECT LDAP_SIZELIMIT_EXCEEDED);
use Net::LDAP::Util qw(escape_filter_value);
use Encode qw(decode_utf8);
use MIME::Base64 qw(decode_base64url);

sub newform {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $search = $self->param('s') // '';
  my $res_tab;

  if ($search ne '') {
    # perform search
    my $ldap = Net::LDAP->new($self->config('ldap_servers'), port => 389, timeout => 10, version => 3);
    unless ($ldap) {
      warn "LDAP creation error: $@";
      return $self->render(text => 'Ошибка подключения к глобальному каталогу.');
    }

    my $mesg = $ldap->bind($self->config('ldap_user'), password => $self->config('ldap_pass'));
    if ($mesg->code) {
      warn 'LDAP bind error: '.$mesg->error;
      return $self->render(text => 'Произошла ошибка авторизации при подключении к глобальному каталогу.');
    }

    # search ldap
    my $esc_search = escape_filter_value($search).'*'; # security filtering
    my $filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(cn=$esc_search)(sAMAccountName=$esc_search)))";
    my $res = $ldap->search(base => $self->config('personnel_ldap_base'), scope => 'sub',
      filter => $filter,
      attrs => ['displayName', 'sAMAccountName', 'objectGUID', 'userAccountControl',
        'title', 'department', 'mail'],
      sizelimit => 5
    );
    if ($res->code && $res->code != LDAP_SIZELIMIT_EXCEEDED && $res->code != LDAP_NO_SUCH_OBJECT) {
      warn 'LDAP search error: '.$res->error;
      return $self->render(text => 'Произошла ошибка поиска в глобальном каталоге.');
    }

    #my $count = $res->count; say "found: $count";
    my $i = 0;
    $res_tab = [];
    for my $entry ($res->entries) {
      #$entry->dump;
      my $uac = $entry->get_value('userAccountControl') || 0x200;
      push @$res_tab, {
        dn => $entry->dn, # we assume dn to be octets string
        cn => decode_utf8($entry->get_value('displayName')),
        disabled => ($uac & 2) == 2,
        login => lc decode_utf8($entry->get_value('sAMAccountName')),
        guid => $entry->get_value('objectGUID'), # binary
        title => decode_utf8($entry->get_value('title')),
        department => decode_utf8($entry->get_value('department')),
        email => decode_utf8($entry->get_value('mail')),
      };

      last if ++$i >= 5;
    }

    $ldap->unbind;
  }

  $self->render(template => 'client/new',
    res_tab => $res_tab,
    search => $search,
  );
}


sub newpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  my $search = $v->optional('s')->param || '';

  my $sel_guid = $v->required('ug')->param;
  if ($v->is_valid) { # check ug
    $sel_guid = $self->guid2string(decode_base64url($sel_guid));
    my $j = { guid => $sel_guid }; # resulting json
    #say $sel_guid;
    $j->{cn} = $v->required('cn', 'not_empty')->param;
    $j->{login} = $v->required('login', 'not_empty')->param;
    $v->optional('desc', 'not_empty');
    $j->{desc} = $v->param if $v->is_valid;
    $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
    $j->{email} = $v->param if $v->is_valid;

    if ($v->has_error) {
      $self->flash(oper => 'Ошибка. Неверные данные. Проверьте учетную запись пользователя.');
      return $self->redirect_to($self->url_for('clientnew')->query(s => $search));
    }

    #$self->log->debug($self->dumper($j));

    # post to system
    $self->render_later;

    $self->ua->post(Mojo::URL->new("/ui/client")->to_abs($self->head_url) => json => $j =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return unless $self->request_success($res);

        # do redirect with a toast
        $self->flash(oper => 'Выполнено успешно.');
        return $self->redirect_to($self->url_for('clients'));
      } # post closure
    );

  } else {
    $self->flash(oper => 'Ошибка. Пользователь не выбран.');
    $self->redirect_to($self->url_for('clientnew')->query(s => $search));
  }
}


# new manual client render form and submit
sub newpainpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(template => 'client/newpain') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  my $j = { guid => '' }; # resulting json
  $j->{cn} = $v->required('cn', 'not_empty')->param;
  $j->{login} = $v->required('login', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
  $j->{email} = $v->param if $v->is_valid;

  # rerender page with errors
  return $self->render(template => 'client/newpain') if $v->has_error;

  #$self->log->debug("J: ".$self->dumper($j));

  # post to system
  $self->render_later;

  $self->ua->post(Mojo::URL->new("/ui/client")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      # do redirect with a toast
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clients'));
    } # post closure
  );
}


sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(client_id => $id, rec => $v);
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

  my $guid = $v->required('guid')->param;
  return $self->render(text => 'Ошибка данных') unless $v->is_valid;

  my $j = { id => $id }; # resulting json
  my $method;
  if (defined $guid && $guid ne '') {
    # edit desc of AD client
    $method = 'PATCH';
    $v->optional('desc');
    $j->{desc} = $v->is_valid ? $v->param : '';

  } else {
    # edit multiple properties of manual client
    $method = 'PUT';
    $j->{guid} = '';
    $j->{cn} = $v->required('cn', 'not_empty')->param;
    $j->{login} = $v->required('login', 'not_empty')->param;
    $v->optional('desc', 'not_empty');
    $j->{desc} = $v->param if $v->is_valid;
    $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
    $j->{email} = $v->param if $v->is_valid;

  }

  #if ($v->has_error) { my @f=@{$v->failed}; $self->log->debug("Failed validation: @f") }

  # rerender page with errors
  if ($v->has_error) {
    $self->render_later;

    # reget $rec back
    $self->ua->get(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) =>
      {Accept => 'application/json'} =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return unless $self->request_success($res);
        return unless my $vv = $self->request_json($res);

        return $self->render(template => 'client/edit', client_id => $id, rec => $vv);
      } # get closure
    );
    return undef;
  }

  #$self->log->debug("J: ".$self->dumper($j));

  # post (put or patch) to system
  my $tx = $self->ua->build_tx($method => Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url)
    => json => $j);
  $self->ua->start($tx =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clients'));
    } # put closure
  );
}


sub replace {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  my $search = $self->param('s') // '';

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      my $res_tab;

      if ($search ne '') {
        # perform search
        my $ldap = Net::LDAP->new($self->config('ldap_servers'), port => 389, timeout => 10, version => 3);
        unless ($ldap) {
          warn "LDAP creation error: $@";
          return $self->render(text => 'Ошибка подключения к глобальному каталогу.');
        }

        my $mesg = $ldap->bind($self->config('ldap_user'), password => $self->config('ldap_pass'));
        if ($mesg->code) {
          warn 'LDAP bind error: '.$mesg->error;
          return $self->render(text => 'Произошла ошибка авторизации при подключении к глобальному каталогу.');
        }

        # search ldap
        my $esc_search = escape_filter_value($search).'*'; # security filtering
        my $filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(|(cn=$esc_search)(sAMAccountName=$esc_search)))";
        my $res = $ldap->search(base => $self->config('personnel_ldap_base'), scope => 'sub',
          filter => $filter,
          attrs => ['displayName', 'sAMAccountName', 'objectGUID', 'userAccountControl',
            'title', 'department', 'mail'],
          sizelimit => 5
        );
        if ($res->code && $res->code != LDAP_SIZELIMIT_EXCEEDED && $res->code != LDAP_NO_SUCH_OBJECT) {
          warn 'LDAP search error: '.$res->error;
          return $self->render(text => 'Произошла ошибка поиска в глобальном каталоге.');
        }

        #my $count = $res->count; say "found: $count";
        my $i = 0;
        $res_tab = [];
        for my $entry ($res->entries) {
          #$entry->dump;
          my $uac = $entry->get_value('userAccountControl') || 0x200;
          push @$res_tab, {
            dn => $entry->dn, # we assume dn to be octets string
            cn => decode_utf8($entry->get_value('displayName')),
            disabled => ($uac & 2) == 2,
            login => lc decode_utf8($entry->get_value('sAMAccountName')),
            guid => $entry->get_value('objectGUID'), # binary
            title => decode_utf8($entry->get_value('title')),
            department => decode_utf8($entry->get_value('department')),
            email => decode_utf8($entry->get_value('mail')),
          };

          last if ++$i >= 5;
        }

        $ldap->unbind;
      }

      $self->render(template => 'client/replace',
        client_id => $id,
        rec => $v,
        res_tab => $res_tab,
        search => $search,
      );
    } # get closure
  );
}


sub replacepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);

  my $search = $v->optional('s')->param || '';

  my $sel_guid = $v->required('ug')->param;
  if ($v->is_valid) { # check ug
    $sel_guid = $self->guid2string(decode_base64url($sel_guid));
    my $j = { guid => $sel_guid }; # resulting json
    #say $sel_guid;
    $j->{cn} = $v->required('cn', 'not_empty')->param;
    $j->{login} = $v->required('login', 'not_empty')->param;
    $v->optional('desc', 'not_empty');
    $j->{desc} = $v->param if $v->is_valid;
    $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
    $j->{email} = $v->param if $v->is_valid;

    if ($v->has_error) {
      $self->flash(oper => 'Ошибка. Неверные данные. Проверьте учетную запись пользователя.');
      return $self->redirect_to($self->url_for('clientreplace')->query(id => $id, s => $search));
    }

    #$self->log->debug('J: '.$self->dumper($j));

    # post to system
    $self->render_later;

    $self->ua->put(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) => json => $j =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return unless $self->request_success($res);

        # do redirect with a toast
        $self->flash(oper => 'Выполнено успешно.');
        return $self->redirect_to($self->url_for('clientedit')->query(id => $id));
      } # put closure
    );

  } else {
    $self->flash(oper => 'Ошибка. Пользователь не выбран.');
    $self->redirect_to($self->url_for('clientreplace')->query(id => $id, s => $search));
  }
}


sub delete {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(client_id => $id, rec => $v);
    } # get closure
  );
}


sub deletepost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  # send (delete) to system
  $self->render_later;

  $self->ua->delete(Mojo::URL->new("/ui/client/$id")->to_abs($self->head_url) =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);

      # do redirect with flash
      $self->flash(oper => 'Выполнено успешно.');
      $self->redirect_to($self->url_for('clients'));
    } # delete closure
  );
}


sub stat {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $client_id = $self->param('id');
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

  $self->ua->get(Mojo::URL->new("/ui/stat/client/$client_id$q")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(
        client_id => $client_id,
        fullrec => $v,
        rep => $reptype,
        activetab => $activetab
      );
    } # get closure
  );
}


1;
