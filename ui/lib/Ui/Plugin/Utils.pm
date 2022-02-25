package Ui::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Ui::Ural::LogColorer;
use Ui::Ural::OperatorResolver;
use Mojo::URL;
use Mojo::ByteStream 'b';
use Mojo::IOLoop;
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $mojo_url = $self->head_url;
  $app->helper(head_url => sub {
    state $head_url = Mojo::URL->new(shift->config('head_url'));
  });


  # $role_or_undef = get_user_role('mylogin');
  $app->helper(get_user_role => sub {
    my ($self, $login) = @_;
    return undef if $login eq 'default';

    my $users = $self->config('users');
    return $users->{$login} if defined $users->{$login};
    return $users->{'default'} if defined $users->{'default'};
    return undef;
  });


  # return undef unless $self->authorize({ admin=>1 });
  $app->helper(authorize => sub {
    my ($c, $roles_href) = @_;

    my $role = $c->stash('remote_user_role');
    return 1 if ($role && $roles_href->{$role});
    $c->app->log->warn("Access is forbidden for role: $role, user: ".$c->stash('remote_user'));
    $c->render(text => 'Доступ запрещён. Обратитесь в группу сетевого администрирования.', status => 401);
    return undef;
  });

  # $self->authorize($self->allow_all_roles);
  $app->helper(allow_all_roles => sub {
    { admin=>1, client=>1 };
  });


  # log_rowcolor singleton
  $app->helper(log_rowcolor => sub {
    shift;
    state $log_colorer = Ui::Ural::LogColorer->new;
    return $log_colorer->color(shift);
  });


  # $self->exists_and_number($value)
  # renders error if not number
  $app->helper(exists_and_number => sub {
    my ($self, $v) = @_;
    unless (defined $v && $v =~ /^\d+$/) {
      $self->render(text => 'Ошибка данных');
      return undef;
    }
    return 1;
  });


  # my $result = eval { $tx->result };
  # $self->request_success($result)
  # renders various errors if $result is not success
  $app->helper(request_success => sub {
    my ($self, $res) = @_;
    unless (defined $res) {
      $self->render(text => 'Ошибка соединения с управляющим сервером');
      return undef;
    }
    unless ($res->is_success) {
      if ($res->is_error) {
        $self->render(text => 'Ошибка запроса: '.substr($res->body, 0, 120));
        return undef;
      }
      $self->render(text => 'Неподдерживаемый ответ');
      return undef;
    }
    return 1;
  });


  # my $result = eval { $tx->result };
  # my $j = $self->request_json($result)
  # renders error if json is undef
  $app->helper(request_json => sub {
    my ($self, $res) = @_;
    my $v = $res->json;
    unless ($v) {
      $self->render(text => 'Ошибка формата данных');
      return undef;
    }
    return $v;
  });


  # $mb = btomb(1024)
  $app->helper(btomb => sub {
    return sprintf('%.1f', $_[1] / 1048576);
  });


  # $b = mbtob(1024)
  $app->helper(mbtob => sub {
    return int($_[1] * 1048576);
  });


  # $guid_str = guid2string($guid_octets)
  $app->helper(guid2string => sub {
    my $strguid = unpack('H*', $_[1]);
    $strguid =~ s/^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w\w\w)/$4$3$2$1-$6$5-$8$7-$9-/;
    return $strguid;
  });


  # my $full_operator_name = oprs($login)
  $app->helper(oprs => sub {
    my ($self, $login) = @_;
    # oprs object singleton
    state $oprs = Ui::Ural::OperatorResolver->new($self->config);
    return $oprs->resolve($login);
  });


  # '10:11:12 11/12/21' = prettify_date('10:11:12 11-12-21')
  $app->helper(prettify_date => sub {
    my $date = $_[1];
    $date =~ s/-/\//g if defined $date;
    return $date;
  });


  # remote audit logging
  $app->helper(raudit => sub {
    my ($self, $m, %param) = @_;
    croak 'Parameter missing' unless defined $m;

    my $sync = $param{sync} // 0;
    my $login = $param{login} // $self->stash('remote_user');

    my $url = Mojo::URL->new('/log')->to_abs($self->head_url);
    if ($sync) {
      my $res = eval { $self->ua->post($url => json
        => { login => $login, audit => $m })->result };
      unless (defined $res) {
        $self->log->error('Audit log request failed, probably connection refused');
      } else {
        $self->log->error('Audit log request error: '.substr($res->body, 0, 40)) if $res->is_error;
      }

    } else {
      $self->ua->post($url => json
        => { login => $login, audit => $m } =>
        sub {
          my ($ua, $tx) = @_;
          my $res = eval { $tx->result };
          unless (defined $res) {
            $self->log->error('Audit log request failed, probably connection refused');
          } else {
            $self->log->error('Audit log request error: '.substr($res->body, 0, 40)) if $res->is_error;
          }
        }
      );
      Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    }
  });


  # 'text' = rt_resolve($rt)
  $app->helper(rt_resolve => sub {
    my ($c, $selector) = @_;
    state %trans = map { $_->[1] => $_->[0] } @{$c->config('rt_names')};
    return $trans{$selector} // 'Неизвестно';
  });


  # 'text' = qs_resolve($qs)
  $app->helper(qs_resolve => sub {
    my ($c, $selector) = @_;
    state %trans = map { $_->[1] => $_->[0] } @{$c->config('qs_names')};
    return $trans{$selector} // 'Неизвестно';
  });


  # 'text' = defjump_resolve($defjump)
  $app->helper(defjump_resolve => sub {
    my ($c, $selector) = @_;
    state %trans = map { $_->[1] => $_->[0] } @{$c->config('defjump_names')};
    return $trans{$selector} // 'Неизвестно';
  });


  # 'text' = speed_plan_resolve($speed_key)
  $app->helper(speed_plan_resolve => sub {
    my ($c, $selector) = @_;
    state %trans = map { $_->{key} => $_->{name} } @{$c->config('speed_plans')};
    return $trans{$selector} // 'Неизвестно';
  });

  # '/img/speed.png' = speed_plan_img($speed_key)
  $app->helper(speed_plan_img => sub {
    my ($c, $selector) = @_;
    state %trans = map { $_->{key} => $_->{img} } @{$c->config('speed_plans')};
    return $trans{$selector} // '';
  });

  # 'speed_key'|'userdef' = get_speed_key($speed_in, $speed_out)
  $app->helper(get_speed_key => sub {
    my ($c, $speed_in, $speed_out) = @_;
    state %trans = map {
      my $in = $_->{in};
      my $out = $_->{out};
      defined $in && defined $out && $in ne '' && $out ne '' ? ("$in$out" => $_->{key}) : ()
    } @{$c->config('speed_plans')};

    return $trans{"$speed_in$speed_out"} // 'userdef';
  });

  # ['name' => 'speed_key', 'data-icon' => 'img'] = array_for_speed_select;
  $app->helper(array_for_speed_select => sub {
    my $c = shift;
    state @arr = map { [$_->{name} => $_->{key}, 'data-icon' => $_->{img}] } @{$c->config('speed_plans')};
    return \@arr;
  });


  # my ($type, $hostname) = split_agent_type($type_or_subsys)
  $app->helper(split_agent_type => sub {
    my ($c, $t) = @_;
    my ($type, $hostname) = (q{}, q{});
    if (defined $t && $t =~ /^([^@]+)(?:@(.*))?$/) {
      $type = $1;
      $hostname = $2 if defined $2;
    }
    return ($type, $hostname);
  });

}

1;
