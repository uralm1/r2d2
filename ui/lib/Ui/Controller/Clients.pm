package Ui::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Net::LDAP qw(LDAP_SUCCESS LDAP_INSUFFICIENT_ACCESS LDAP_NO_SUCH_OBJECT LDAP_SIZELIMIT_EXCEEDED);
use Net::LDAP::Util qw(escape_filter_value);
use Encode qw(decode_utf8);
use MIME::Base64 qw(decode_base64url);

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($active_page);

  $self->render_later;

  $self->ua->get(Mojo::URL->new('/ui/list')->to_abs($self->head_url)->
    query({page => $active_page, lop => $self->config('lines_on_page')}) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>'Ошибка формата данных') unless $v;
        return $self->render(rec => $v);
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 60));
      }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # get closure
  );
}


sub newget {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $search = $self->param('s');
  my $res_tab;

  if ($search) {
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

  } else {
    $search = '';
  }

  $self->render(template => 'clients/new',
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
      return $self->redirect_to($self->url_for('clientsnew')->query(s => $search));
    }

    #$self->log->debug($self->dumper($j));

    # post to system
    $self->render_later;

    $self->ua->post(Mojo::URL->new("/ui/client")->to_abs($self->head_url) => json => $j =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

        if ($res->is_success) {
          # do redirect with a toast
          $self->flash(oper => 'Выполнено успешно.');
          return $self->redirect_to($self->url_for('clients'));
        } else {
          if ($res->is_error) {
            return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 120));
          }
          return $self->render(text=>'Неподдерживаемый ответ');
        }
      } # post closure
    );

  } else {
    $self->flash(oper => 'Ошибка. Пользователь не выбран.');
    $self->redirect_to($self->url_for('clientsnew')->query(s => $search));
  }
}


# new manual client render form and submit
sub newpainpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(template => 'clients/newpain') unless $v->has_data;

  #$self->log->debug("I: ".$self->dumper($v->input));

  my $j = { guid => '' }; # resulting json
  $j->{cn} = $v->required('cn', 'not_empty')->param;
  $j->{login} = $v->required('login', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
  $j->{email} = $v->param if $v->is_valid;

  # rerender page with errors
  return $self->render(template => 'clients/newpain') if $v->has_error;

  #$self->log->debug("J: ".$self->dumper($j));

  # post to system
  $self->render_later;

  $self->ua->post(Mojo::URL->new("/ui/client")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        # do redirect with a toast
        $self->flash(oper => 'Выполнено успешно.');
        $self->redirect_to($self->url_for('clients'));
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 120));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # post closure
  );
}


sub editget {
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
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>'Ошибка формата данных') unless $v;
        return $self->render(template => 'clients/edit',
          client_id => $id, rec => $v);
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 60));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # get closure
  );
}


1;
