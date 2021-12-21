package Ui::Plugin::Html;
use Mojo::Base 'Mojolicious::Plugin';

use Ui::Ural::Changelog;
use Mojo::ByteStream 'b';
use HTTP::BrowserDetect;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # html_or_undef = check_newversion
  $app->helper(check_newversion => sub {
    my $c = shift;
    my $coo = $c->cookie('versionR');
    my $cur_version = $c->stash('version');
    if (defined $coo) {
      if ($coo ne $cur_version) {
        $c->cookie('versionR' => $cur_version, {path => '/', expires=>time+360000000});
        if (my $changelog = Ui::Ural::Changelog->new($cur_version)) {
          return b('<div id="newversion-modal" class="modal modal-fixed-footer">
<div class="modal-content"><h4>Новая версия '.$changelog->get_version.
'</h4><p><b>Последние улучшения и новинки:</b></p><pre class="newversion-hist">'.$changelog->get_changelog.
'</pre></div><div class="modal-footer"><a href="#!" class="modal-close waves-effect waves-green btn-flat">Отлично</a></div></div>');
        }
      }
    } else {
      $c->cookie('versionR' => $cur_version, {path => '/', expires=>time+360000000});
    }

    return undef;
  });


  # 1_or_undef = check_newfeature(feature_no => feature_version)
  # current features:
  # 1 - multiple devices support
  $app->helper(check_newfeature => sub {
    my ($c, $fid, $fver) = @_;
    $fver //= 1;
    my $coo_name = "feature$fid";
    my $coo = $c->cookie($coo_name);
    if (!defined $coo || $coo ne $fver) {
      $c->cookie($coo_name => $fver, {path => '/', expires=>time+360000000});
      return 1;
    }
    return undef;
  });


  # 1/undef = check_browser
  # 1 - browser is ok
  $app->helper(check_browser => sub {
    my $c = shift;
    my $br = $c->session('br');
    if (!defined $br) {
      my $ua = HTTP::BrowserDetect->new($c->req->headers->user_agent);
      #say 'BROWSER CHECK!!! '.$ua->browser_major;
      if (
        $ua->ie ||
        ($ua->firefox && $ua->browser_major <= 78) ||
        ($ua->chrome && $ua->browser_major < 78) ||
        ($ua->edge && $ua->browser_major <= 78) ||
        $ua->edgelegacy
      ) {
        # bad browser
        $br = 0;
      } else {
        # good browser
        $br = 1;
      }
      $c->session(br => $br);
    }
    return $br > 0 ? 1 : undef;
  });


  # 'html' = img_hmtl('flagged')
  # 'html' = img_html('blocked' => $qs)
  $app->helper(img_html => sub {
    my ($c, $key, $selector) = @_;

    state $_source = {
      flagged => '<i class="material-icons tiny green-text table-tooltips" data-position="bottom" data-tooltip="Устройство не синхронизировано">sync</i>',
      no_dhcp => '<i class="material-icons tiny green-text table-tooltips" data-position="bottom" data-tooltip="Устройство не использует DHCP (VPN или статический адрес)">lock_open</i>',
      blocked => [
        '<i class="material-icons tiny blue-text table-tooltips" data-position="bottom" data-tooltip="Заблокировано">help</i>',
        '<i class="material-icons tiny amber-text table-tooltips" data-position="bottom" data-tooltip="Предупреждение по лимиту">warning</i>',
        '<i class="material-icons tiny amber-text table-tooltips" data-position="bottom" data-tooltip="Активировано ограничение по лимиту (Букашка)">cancel</i>',
        '<i class="material-icons tiny red-text table-tooltips" data-position="bottom" data-tooltip="Активирована блокировка по лимиту (Отключен)">cancel</i>'
      ]
    };

    if ($key eq 'blocked') {
      return b('') unless defined $selector;
      return b($selector =~ /^[123]$/ ? $_source->{$key}[$selector] : $_source->{$key}[0]);
    }
    return b($_source->{$key});
  });


  # 'html' = panel_html('flagged')
  # 'html' = panel_html('blocked' => $qs)
  $app->helper(panel_html => sub {
    my ($c, $key, $selector) = @_;

    state $_source = {
      start => '<div class="row"><div class="col s12 m12 l10"><div class="card-panel list-warning-panel">',
      end => '</div></div></div>',
      flagged => '<div class="green-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Данное устройство не синхронизировано. Ожидайте синхронизации...</b></span></div>',
      lost => '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Данный клиент отсутствует в глобальном каталоге. Выполните замену или удаление.</b></span></div>',
      lostlist => '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Имеются клиенты, отсутствующие в глобальном каталоге. Выполните замену или удаление.</b></span></div>',
      manual => '<div><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Данный клиент создан вручную. Рекомендуется перейти на использование глобального каталога.</span></div>',
      painlist => '<div><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Имеются клиенты, созданные вручную. Рекомендуется перейти на использование глобального каталога.</span></div>',
      blocked => [
        '<div class="blue-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Данное устройство заблокировано. Режим неизвестен.</b></span></div>',
        '<div class="amber-text text-darken-3"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Активировано предупреждение по лимиту трафика. Режим - предупреждение.</b></span></div>',
        '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Активировано ограничение по лимиту трафика. Режим - ограничение скорости.</b></span></div>',
        '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Активирована блокировка по лимиту трафика. Режим - блокировка доступа.</b></span></div>',
      ],
      'blocked-stat' => '<div class="amber-text text-darken-3"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Вы исчерпали лимит трафика на одном из Ваших устройств. Подробности ниже.</b></span></div>',
      'blocked-clientedit' => '<div class="amber-text text-darken-3"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! У клиента исчерпан лимит трафика на одном из устройств. Подробности на странице статистики.</b></span></div>',
      'old-browser' => '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Вы используете устаревшую версию Интернет-броузера. Возможно некоторые элементы будут отображены неверно или не будут работать. Обновите Интернет-броузер.</b></span></div>',
    };

    if ($key eq 'blocked') {
      return b('') unless defined $selector;
      return b($selector =~ /^[123]$/ ? $_source->{$key}[$selector] : $_source->{$key}[0]);
    }
    return b($_source->{$key});
  });

}

1;
