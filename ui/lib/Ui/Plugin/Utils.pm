package Ui::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Ui::Ural::LogColorer;
use Ui::Ural::OperatorResolver;
use Ui::Ural::Changelog;;
use Mojo::URL;
use Mojo::Util qw(xml_escape);

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


  # html_or_undef = check_newversion
  $app->helper(check_newversion => sub {
    my $c = shift;
    my $coo = $c->cookie('versionA');
    my $cur_version = $c->stash('version');
    if (defined $coo) {
      if ($coo ne $cur_version) {
        $c->cookie('versionA' => $cur_version, {path => '/', expires=>time+360000000});
        if (my $changelog = Ui::Ural::Changelog->new($cur_version)) {
          return '<div id="newversion-modal" class="modal modal-fixed-footer">
<div class="modal-content"><h4>Новая версия '.$changelog->get_version.
'</h4><p><b>Последние улучшения и новинки:</b></p><pre class="newversion-hist">'.$changelog->get_changelog.
'</pre></div><div class="modal-footer"><a href="#!" class="modal-close waves-effect waves-green btn-flat">Отлично</a></div></div>';
        }
      }
    } else {
      $c->cookie('versionA' => $cur_version, {path => '/', expires=>time+360000000});
    }

    return undef;
  });


  # $mb = btomb(1024)
  $app->helper(btomb => sub {
    return sprintf('%.1f', $_[1] / 1048576);
  });


  # $b = mbtob(1024)
  $app->helper(mbtob => sub {
    return int($_[1] * 1048576);
  });


  # "1.1 Мб" = traftomb(1024)
  # "н/д" = traftomb(-1)
  $app->helper(traftomb => sub {
    my $b = $_[1];
    return 'н/д' if $b < 0;
    return $_[0]->btomb($b).' Мб';
  });

  # "<td>~1.1 Мб (~1024 байт)</td><td>н/д</td>" = traftotd({in=>1024,out=>-1,fuzzy_in=>1})
  $app->helper(traftotd => sub {
    my $self = $_[0];
    my $t = $_[1];
    my $r = '';
    for (qw/in out/) {
      my $b = $t->{$_};
      if (!defined $b || $b < 0) {
        $r .= '<td>н/д</td>';
      } else {
        my $fuz = $t->{"fuzzy_$_"} ? '~' : '';
        $r .= '<td>'.xml_escape($fuz.$self->btomb($b)." Мб ($fuz$b байт)").'</td>';
      }
    }
    return $r;
  });


  $app->helper(days_in => sub {
    my ($self, $year, $month) = @_;
    # $month is 0..11
    #               1  2  3  4  5  6  7  8  9 10 11 12
    my @mltable = (31, 0,31,30,31,60,31,31,30,31,30,31);
    return $mltable[$month] unless $month == 2;
    return 28 unless $self->is_leap($year);
    return 29;
  });

  $app->helper(is_leap => sub {
    my $y = $_[1];
    return ( ($y % 4 == 0) and ($y % 400 == 0 or $y % 100 != 0) ) || 0;
  });

  $app->helper(get_js_date => sub {
    my $d = $_[1];
    if ($d =~ /^(\d+)[-\/](\d+)[-\/](\d+)$/) {
      my $m = $2 - 1;
      return "$3,$m,$1";
    } elsif ($d =~ /^(\d+)[-\/](\d+)$/) {
      my $m = $1 - 1;
      return "$2,$m,1";
    }
    return undef;
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

}

1;
