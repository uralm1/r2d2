package Ui::Plugin::Html;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::ByteStream 'b';

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

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
      flagged => '<div class="green-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Данное устройство не синхронизировано. Ожидайте синхронизации...</span></div>',
      lost => '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Данный клиент отсутствует в глобальном каталоге. Выполните замену или удаление.</b></span></div>',
      lostlist => '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ! Имеются клиенты, отсутствующие в глобальном каталоге. Выполните замену или удаление.</b></span></div>',
      manual => '<div><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Данный клиент создан вручную. Рекомендуется перейти на использование глобального каталога.</span></div>',
      painlist => '<div><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Имеются клиенты, созданные вручную. Рекомендуется перейти на использование глобального каталога.</span></div>',
      blocked => [
        '<div class="blue-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Данное устройство заблокировано. Режим неизвестен.</span></div>',
        '<div class="amber-text text-darken-3"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Активировано предупреждение по лимиту трафика. Режим - предупреждение.</span></div>',
        '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Активировано ограничение по лимиту трафика. Режим - ограничение скорости.</span></div>',
        '<div class="red-text"><i class="material-icons tiny">warning</i><span>&nbsp;<b>ВНИМАНИЕ!</b> Активирована блокировка по лимиту трафика. Режим - блокировка доступа.</span></div>',
      ]
    };

    if ($key eq 'blocked') {
      return b('') unless defined $selector;
      return b($selector =~ /^[123]$/ ? $_source->{$key}[$selector] : $_source->{$key}[0]);
    }
    return b($_source->{$key});
  });

}

1;
