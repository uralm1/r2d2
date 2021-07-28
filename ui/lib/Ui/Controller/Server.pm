package Ui::Controller::Server;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Regexp::Common qw(number net);

sub edit {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/server/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>'Ошибка формата данных') unless $v;
        return $self->render(srv_id => $id, srv_rec => $v);
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 60));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # get closure
  );
}


sub editpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  my $id = $v->optional('id')->param;
  return unless $self->exists_and_number($id);

  my $j = { id => $id }; # resulting json
  $j->{cn} = $v->required('cn', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
  $j->{email} = $v->param if $v->is_valid;
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
  return $self->render(template => 'server/edit', srv_id => $id) if $v->has_error;

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
  $j->{limit_in} = $self->mbtob($limit_in);

  #$self->log->debug($self->dumper($j));

  # post (put) to system
  $self->render_later;

  $self->ua->put(Mojo::URL->new("/ui/server/$id")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        # do redirect with flash
        $self->flash(oper => 'Выполнено успешно.');
        $self->redirect_to($self->url_for('clients'));
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 120));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # put closure
  );
}


# new server render form
sub newform {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  return $self->render(template => 'server/new');
}


# new server submit
sub newpost {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $v = $self->validation;
  return $self->render(text=>'Не дал показания') unless $v->has_data;

  my $j = { }; # resulting json
  $j->{cn} = $v->required('cn', 'not_empty')->param;
  $v->optional('desc', 'not_empty');
  $j->{desc} = $v->param if $v->is_valid;
  $v->optional('email', 'not_empty')->like(qr/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/);
  $j->{email} = $v->param if $v->is_valid;
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
  return $self->render(template => 'server/new') if $v->has_error;

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
  $j->{limit_in} = $self->mbtob($limit_in);

  #$self->log->debug($self->dumper($j));

  # post to system
  $self->render_later;

  $self->ua->post(Mojo::URL->new("/ui/server")->to_abs($self->head_url) => json => $j =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        # do redirect with flash
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


sub delete {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/server/$id")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>'Ошибка формата данных') unless $v;
        return $self->render(srv_id => $id, srv_rec => $v);
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 60));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
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

  $self->ua->delete(Mojo::URL->new("/ui/server/$id")->to_abs($self->head_url) =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        # do redirect with flash
        $self->flash(oper => 'Выполнено успешно.');
        $self->redirect_to($self->url_for('clients'));
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 120));
        }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # put closure
  );
}


1;
