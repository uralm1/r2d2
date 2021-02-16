#!/usr/bin/perl
# This is the part of R2D2
# Administration interface
# author: Ural Khassanov, 2013
#

use lib '..';
require 'r2db.pm';
require 'r2ad.pm';
require 'r2utils.pm';

use strict;
use warnings;
use Encode;
use URI::Escape;
use NetAddr::IP;
use NetAddr::MAC;

&R2utils::set_modname('adm');
&R2utils::set_footername('Интерфейс администрирования');
&R2utils::set_title('R2D2 Администратор');

my $q = &R2utils::cgi; # set short name to query object

my %rt_names = (
  '0' => 'Уфанет',
  '1' => 'Билайн',
);

my %defjump_names = (
  'ACCEPT' => 'ACCEPT (весь ip)',
  'HTTP_ICMP' => 'HTTP_ICMP (http, icmp)',
  'HTTP_IM_ICMP' => 'HTTP_IM_ICMP (http, mail, im, icmp)',
  'ICMP_ONLY' => 'ICMP_ONLY (icmp, just for fun)',
  'DROP' => 'DROP (отключен)',
);

my @speed_list = qw ( 10241280 12801280 15361536 20482048 40964096 81928192 userdef );
my %speed_plans = (
'10241280' => [ 'Рабочая улитка (1/1.2 мбит)', 
  'quantum 6400 rate 1mbit prio 5', 'quantum 6400 rate 1mbit ceil 1280kbit prio 5'],
'12801280' => [ 'Почётный пенсионер (1.3/1.3 мбит)',
  'quantum 6400 rate 1mbit ceil 1280kbit prio 5', 'quantum 6400 rate 1mbit ceil 1280kbit prio 5'],
'15361536' => [ 'Адвокат бизнесмена (1.5/1.5 мбит)',
  'quantum 6400 rate 1mbit ceil 1536kbit prio 5', 'quantum 6400 rate 1mbit ceil 1536kbit prio 5'],
'20482048' => [ 'Директор по продажам (2/2 мбит)',
  'quantum 6400 rate 1mbit ceil 2mbit prio 5', 'quantum 6400 rate 1mbit ceil 2mbit prio 5'],
'40964096' => [ 'Помощник президента (4/4 мбит)',
  'quantum 6400 rate 1mbit ceil 4mbit prio 5', 'quantum 6400 rate 1mbit ceil 4mbit prio 5'],
'81928192' => [ 'Бог интернета (8/8 мбит)',
  'quantum 6400 rate 1mbit ceil 8mbit prio 5', 'quantum 6400 rate 1mbit ceil 8mbit prio 5'],
'userdef' => [ 'Индивидуал (индивидуальные настройки)', '', ''],
);
# automatically build separate names hash
my %speed_names = map { $_ => $speed_plans{$_}->[0] } @speed_list;

my %qs_names = (
  '0' => 'Отключена (Анлим)',
  '1' => 'Мягкая (Извещение)',
  '2' => 'Средняя (Снижение скорости)',
  '3' => 'Жесткая (Отключение)',
);


&R2db::open_dbs();
my $dbh_inet = &R2db::dbh_inet; # set short name for db handle object

###
# parameters switch
my $kk;
if (&R2utils::is_admin) {
  if ($q->param('new')) {
    &newuser;
  } elsif ($kk = $q->param('info')) {
    &userinfo($kk);
  } elsif ($kk = $q->param('edit')) {
    &edituser($kk);
  } elsif ($kk = $q->param('del')) {
    &deluser($kk);
  } elsif ($kk = $q->param('editlimit')) {
    &edituserlimit($kk);
  } elsif ($q->url_param('new') && $q->param('submit_new')) {
    &newuser_submit;
  } elsif (($kk = $q->url_param('edit')) && $q->param('submit_edit')) {
    &edituser_submit($kk);
  } elsif (($kk = $q->url_param('editlimit')) && $q->param('submit_limit')) {
    &edituserlimit_submit($kk);
  } elsif (($kk = $q->url_param('info')) && $q->param('submit_info')) {
    &userinfo_submit($kk);
  } elsif ($kk = $q->param('log')) {
    &viewlog($kk);
  } else {
    &viewusers($q->param('sort'));
  }
} else {
  &R2utils::print_bad_query;
}

&R2db::close_dbs();

exit;

###

# &print_defjump_field("HTTP_ICMP")
sub print_defjump_field {
  my $defjump = shift;
  $defjump = 'ACCEPT' unless $defjump;
  print "<tr><td>Правило:</td><td>";
  my @v = sort keys(%defjump_names);
  print $q->popup_menu(-name => "defjump",
    -values => \@v,
    -default => $defjump,
    -labels => \%defjump_names, 
  );
  print "</td><td></td></tr>";
}

# &print_speed_fields(384512, 'rate 256kbit prio 5', 'rate 256kbit prio 5')
sub print_speed_fields {
  my $speed_key = shift;
  my $speed_userdef_in = shift;
  my $speed_userdef_out = shift;
  $speed_key = $speed_list[0] unless $speed_key;
  $speed_userdef_in = '' unless $speed_userdef_in;
  $speed_userdef_out = '' unless $speed_userdef_out;
  print "<tr><td>Скорость:</td><td>";
  print $q->popup_menu(-name => "speed",
    -values => \@speed_list,
    -default => $speed_key,
    -labels => \%speed_names,
  );
  print "</td><td>";
  foreach (@speed_list) {
    print "<img class=\"db\" src=\"img/speed$_.png\" title=\"$speed_names{$_}\" width=\"16\" height=\"16\">";
  }
  print "*</td></tr>";
  print "<tr><td colspan=\"2\">*&nbsp;индивидуальные настройки скорости:</td><td></td></tr>";
  print "<tr><td>&nbsp;&nbsp;входящая:</td><td><input type=\"text\" name=\"speed_userdef_in\" value=\"$speed_userdef_in\" size=\"50\" maxlength=\"100\"></td><td>Формат: quantum 6400 rate 256kbit ceil 384kbit prio 5</td></tr>";
  print "<tr><td>&nbsp;&nbsp;исходящая:</td><td><input type=\"text\" name=\"speed_userdef_out\" value=\"$speed_userdef_out\" size=\"50\" maxlength=\"100\"></td><td>** Если пустое, используется входящая.</td></tr>";
}

# &print_nodhcp_field("1")
sub print_nodhcp_field {
  my $no_dhcp = shift;
  $no_dhcp = 0 unless defined $no_dhcp;
  print "<tr><td></td><td>";
  print $q->checkbox(-name => "nodhcp",
    -checked => $no_dhcp,
    -label => 'Клиент не использует DHCP'
  );
  print "</td><td>Для VPN пользователей и статических IP. Синхронизация с DHCP выполняться не будет.</td></tr>";
}

# &print_rt_field("0")
sub print_rt_field {
  my $rt = shift;
  $rt = '0' unless defined $rt;
  print "<tr><td>Провайдер:</td><td>";
  my @v = sort keys(%rt_names);
  print $q->popup_menu(-name => "rt",
    -values => \@v,
    -default => $rt,
    -labels => \%rt_names,
  );
  print "</td><td>Выбор маршрутизации для клиента.</td></tr>";
}

# &print_quota_fields("0", 4096, "1")
sub print_quota_fields {
  my $qs = shift;
  my $limit_in = shift;
  my $email_notify = shift;
  $qs = '2' unless defined $qs;
  $limit_in = '1024' unless defined $limit_in;
  $email_notify = 1 unless defined $email_notify;

  print "<tr><td>Режим&nbsp;квоты:</td><td>";
  my @v = sort keys(%qs_names);
  print $q->popup_menu(-name => "qs",
    -values => \@v,
    -default => $qs,
    -labels => \%qs_names,
  );
  print "</td><td>Метод работы квотировщика.</td></tr>";
  print "<tr><td>Лимит:</td><td><input type=\"text\" name=\"limit\" value=\"$limit_in\" maxlength=\"30\"></td><td>Мегабайт в месяц. Формат: число без добавления \"Мб\".</td></tr>";
  &print_email_notify_field($email_notify, "Оповещать пользователя по e-mail об окончании квоты. Адрес e-mail из Active Directory.")
}

# &print_email_notify_field("1", "Оповещать пользователя по e-mail об окончании квоты.")
sub print_email_notify_field {
  my $email_notify = shift;
  my $comm = shift;
  $email_notify = 1 unless defined $email_notify;
  $comm = '' unless defined $comm;
  print "<tr><td></td><td>";
  print $q->checkbox(-name => "email_notify",
    -checked => $email_notify,
    -label => 'Уведомление по e-mail'
  );
  print "</td><td>$comm</td></tr>";
}

# &get_blocked_img($qs)
sub get_blocked_img {
  my $qs = shift;
  my $img;
  if ($qs == 0) { # umlim
    $img = '';
  } elsif ($qs == 1) { # warned
    $img = '<img src="img/warned.png" width="16" height="16" title="Предупреждение по лимиту">';
  } elsif ($qs == 2) { # limited
    $img = '<img src="img/limited.png" width="16" height="16" title="Активировано ограничение по лимиту (Букашка)">';
  } else { # blocked
    $img = '<img src="img/blocked.png" width="16" height="16" title="Активирована блокировка по лимиту (Отключен)">';
  }
  return $img;
}

###
sub viewusers {
  my $sort = shift;
  if (!$sort) { $sort = 'ip'; }
  elsif ($sort ne 'ip' && $sort ne 'login' && $sort ne 'rt' && $sort ne 'lim') { $sort = 'ip'; }
  my $sort1 = '';
  if ($sort eq 'rt') {
    $sort1 = ', ip ASC';
  } elsif ($sort eq 'lim') {
    $sort = 'sum_limit_in';
    $sort1 = ', ip ASC';
  }

  &R2utils::print_start_hdr;
  print "<p>Привет, господин&nbsp;<b>",&R2utils::remote_user,"</b>&nbsp;! На всякий случай я буду регистрировать все Ваши действия.</p>";
  print "<p><b>&gt; Просмотр логов:</b> <a href=\"adm.cgi?log=agent\">Лог агентов</a>, <a href=\"adm.cgi?log=admin\">Лог администрирования</a>, <a href=\"changelog.html\">ChangeLog (",&R2utils::version,")</a>, <a href=\"adm.cgi?log=oplog\">Oplog</a>.</p>";
  print "<p><b>&gt; Просмотр отчётов:</b> <a href=\"admrep.cgi?type=leech\">Топ скачивающих</a>, <a href=\"admrep.cgi?type=macdup\">Mac-дубликаты</a>, <a href=\"admrep.cgi?type=users\">Списки пользователей</a>, <a href=\"https://cacti.uwc.ufanet.ru/graph_view.php?action=tree&tree_id=4\">Загрузка каналов</a>.</p>";

  print "<p><b>&gt; Управление списком пользователей:</b></p>";
  my $s = $dbh_inet->prepare("SELECT clients.login, clients.desc, bot, ip, mac, rt, defjump, speed_in, speed_out, s.sync_rt, s.sync_fw, s.sync_dhcp, no_dhcp, qs, limit_in, sum_limit_in, profile, id \
FROM clients, clients_sync s WHERE clients.login = s.login ORDER BY $sort ASC $sort1");
  $s->execute;

  print "<script>function checkdel(ll){return confirm(\"Удалить пользователя: \"+ll+\"?\\n\\nВы уверены?\");}</script>";

  my $sort_login_img = ($sort eq 'login') ? '<img src="img/sort.png" width="16" height="16">':'';
  my $sort_ip_img = ($sort eq 'ip') ? '<img src="img/sort.png" width="16" height="16">':'';
  my $sort_rt_img = ($sort eq 'rt') ? '<img src="img/sort.png" width="16" height="16">':'';
  my $sort_lim_img = ($sort eq 'sum_limit_in') ? '<img src="img/warned.png" width="16" height="16" title="Отсортировано по остатку лимита">':'';
  print "<table class=\"db\"><tr><th><a href=\"adm.cgi?new=user\"><img class=\"db\" src=\"img/plus.png\" width=\"24\" height=\"24\" alt=\"+\" title=\"Добавить пользователя\"></a></th><th><a href=\"adm.cgi?sort=login\">Логин</a>$sort_login_img</th><th><a href=\"adm.cgi?sort=ip\">IP</a>$sort_ip_img</th><th>mac</th><th><a href=\"adm.cgi?sort=rt\">Провайдер</a>$sort_rt_img</th><th style=\"min-width:120px;\"><a href=\"adm.cgi?sort=lim\" title=\"Сортировать по остатку лимита\">Лимиты</a>$sort_lim_img</th><th>Правило</th><th>Комментарий, #заявка</th><th></th><th></th><th></th><th></th></tr>\n";

  my $i = 1;
  while (my ($login, $desc, $bot, $dbip, $dbmac, $rt, $defjump, $speed_in, $speed_out, $sync_rt, $sync_fw, $sync_dhcp, $no_dhcp, $qs, $limit_in, $sum_limit_in, $profile, $id) = $s->fetchrow_array) {
    my $ip = NetAddr::IP->new($dbip);
    my $urllogin = uri_escape($login);
    my $tr_style = ($sum_limit_in == 0) ? 'background: #d4d9de' : '';
    $tr_style = ($sync_rt || $sync_fw || $sync_dhcp) ? 'background: #ffeac2' : $tr_style;
    print "<tr style=\"$tr_style\" id=\"",CGI::escapeHTML($login),"\"><td>$i</td>";
    my $blocked_img = ($sum_limit_in <= 0) ? &get_blocked_img($qs) : '';

    my @ll;
    push @ll, 'ROUTER' if $sync_rt;
    push @ll, 'FW' if $sync_fw;
    push @ll, 'DHCP' if $sync_dhcp;
    my $upd_title = 'Синхронизация '.join(', ', @ll);
    my $upd_img = (@ll) ? "<img src=\"img/sync.png\" width=\"16\" height=\"16\" title=\"$upd_title\">":'';
    my $static_img = ($no_dhcp) ? '<img src="img/static.png" width="16" height="16" title="Клиент не использует DHCP (VPN или статический адрес)">':'';
    my $bot_img = ($bot) ? '<img src="img/bot.png" width="16" height="16" title="Клиент не включается в отчеты по пользователям">':'';
    print "<td><a href=\"adm.cgi?info=$urllogin\">",CGI::escapeHTML($login),"</a>$static_img$bot_img$upd_img</td>";
    print "<td>",($ip)?$ip->addr:'---',"</td>";
    print "<td>",CGI::escapeHTML($dbmac),"</td>";
    binmode STDOUT, ':utf8';
    print "<td>",CGI::escapeHTML(decode_utf8($rt_names{$rt})),"</td>";
    binmode STDOUT;

    # extract speed settings
    my $speed_name = 'userdef';
    while (my ($key, $ref) = each %speed_plans) {
      if ($speed_in eq $ref->[1] && $speed_out eq $ref->[2]) {
	$speed_name = $key; #don't exit loop here
      }
    }
    my $speed_title = ($speed_name eq 'userdef') ? "Индивидуал:\nвходящая: $speed_in\nисходящая: $speed_out" : $speed_names{$speed_name};
    my $speed_img = "<img class=\"db\" src=\"img/speed$speed_name.png\" title=\"$speed_title\">";
    my $qstr = ($qs == 0) ? '*Анлим*' : &R2utils::btomb($limit_in).'&nbsp;Мб';

    print "<td>$blocked_img$speed_img<span title=\"Режим квоты: $qs_names{$qs}\nОсталось: ",&R2utils::btomb($sum_limit_in),"&nbsp;Мб из ",&R2utils::btomb($limit_in),"&nbsp;Мб\"><a href=\"rep.cgi?user=$urllogin\">$qstr</a></span><a href=\"adm.cgi?editlimit=$urllogin\"><img class=\"db\" src=\"img/edit.png\" width=\"16\" height=\"16\" title=\"Изменить лимит\"></a></td>";
    print "<td>",CGI::escapeHTML($defjump),"</td>";
    binmode STDOUT, ':utf8';
    print "<td>",CGI::escapeHTML(decode_utf8($desc)),"</td>";
    binmode STDOUT;
    print "<td><a href=\"adm.cgi?edit=$urllogin\"><img class=\"db\" src=\"img/edit.png\" width=\"16\" height=\"16\" alt=\"E\" title=\"Редактировать\"></a></td>";
    print "<td><a href=\"adm.cgi?del=$urllogin\" onclick=\"return checkdel('$login')\"><img class=\"db\" src=\"img/delete.png\" width=\"16\" height=\"16\" alt=\"X\" title=\"Удалить пользователя\"></a></td>";
    print "<td>$profile</td>";
    print "<td>$id</td>";
    print "</tr>";
    $i++;
  }
  $s->finish;

  print "</table>\n";
  &R2utils::print_end_hdr;
}


sub newuser {
  &R2utils::print_start_hdr;
  print $q->h2("Добавление нового пользователя");
  print <<HTML_FORM;
<form action="adm.cgi?new=user" method="POST">
<table>
<tr><td>Логин:</td><td><input type="text" name="login" size="30" maxlength="30"></td><td>Логин пользователя в AD</td></tr>
<tr><td>Комментарий:</td><td><input type="text" name="desc" size="50" maxlength="255"></td><td>Дополнительная информация, #заявки (пользователям не видно)</td></tr>
<tr><td>IP:</td><td><input type="text" name="ip" value="10.15.0." maxlength="30"></td><td>IPv4 (xxx.xxx.xxx.xxx)</td></tr>
<tr><td>mac:</td><td><input type="text" name="mac" size="30" maxlength="30"></td><td>Eui-48 ethernet MAC (xx:xx:xx:xx:xx:xx)</td></tr>
HTML_FORM
  &print_nodhcp_field;
  &print_rt_field;
  &print_defjump_field;
  &print_speed_fields;
  &print_quota_fields;
  print <<HTML_FORM;
</table>
<p>Применение изменений произойдет в течение 30 мин. См. значок синхронизации маршрутизаторов и DHCP в списке пользователей.<br/>
По завершении синхронизации DHCP необходимо выполнить ipconfig /release, ipconfig /renew на компьютере клиента.</p>
<p><input type="submit" name="submit_new" value="Добавить пользователя">
<input type="button" value="Отмена" onclick="window.location.replace('adm.cgi')"></p>
</form>
HTML_FORM
  &R2utils::print_end_hdr;
}


sub newuser_submit {
  my ($login, $desc, $ip, $mac, $rt, $defjump, $speed, $speed_userdef_in, $speed_userdef_out, $qs, $limit) = (
    $q->param('login'),
    $q->param('desc'),
    $q->param('ip'),
    $q->param('mac'),
    $q->param('rt'),
    $q->param('defjump'),
    $q->param('speed'),
    $q->param('speed_userdef_in'),
    $q->param('speed_userdef_out'),
    $q->param('qs'),
    $q->param('limit'),
  );
  my $email_notify = $q->param('email_notify');
  my $nodhcp = $q->param('nodhcp');
  my $maco = eval { NetAddr::MAC->new($mac) };

  if ($login && $ip && $mac && $maco && defined($rt) && $defjump && (my $ipo = NetAddr::IP->new($ip)) && $speed && defined($qs) && defined($limit)) {
    # format speed value
    if ($speed ne 'userdef') {
      $speed_userdef_in = $speed_plans{$speed}->[1];
      $speed_userdef_out = $speed_plans{$speed}->[2];
    }
    $speed_userdef_in = '' unless $speed_userdef_in; #if not in %speed_plans
    $speed_userdef_out = $speed_userdef_in unless $speed_userdef_out;

    my $limit_bytes = &R2utils::mbtob($limit);
    # insert new record
    my $ql = $dbh_inet->quote($login);
    my $sql = sprintf "INSERT INTO clients \
(login, clients.desc, email_notify, create_time, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, qs, limit_in, sum_limit_in, profile) \
VALUES (%s, %s, %s, NOW(), %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'plk')",
    $ql,
    $dbh_inet->quote($desc),
    ($email_notify) ? '1' : '0',
    $dbh_inet->quote($ipo->numeric),
    $dbh_inet->quote($maco->as_microsoft),
    $dbh_inet->quote($rt),
    $dbh_inet->quote($defjump),
    $dbh_inet->quote($speed_userdef_in),
    $dbh_inet->quote($speed_userdef_out),
    ($nodhcp) ? '1' : '0',
    $dbh_inet->quote($qs),
    $dbh_inet->quote($limit_bytes),
    $dbh_inet->quote($limit_bytes);
    if ($dbh_inet->do($sql)) { #success?
      my $id = $dbh_inet->last_insert_id(undef, undef, 'clients', 'id');
      &R2db::dblog("добавление пользователя $id, $login, $ip, провайдер $rt_names{$rt}, режим квоты $qs_names{$qs}.");
      # mark client for syncronization
      $dbh_inet->do("INSERT INTO clients_sync (client_id, login, sync_rt, sync_fw, sync_dhcp) VALUES ($id, $ql, 1, 1, 1)") or
        &R2db::dblog("ошибка. Невозможно пометить пользователя $login для синхронизации.");
      # insert starting amonthly record
      $dbh_inet->do("INSERT INTO amonthly (client_id, login, date, m_in, m_out) VALUES ($id, $ql, CURDATE(), 0, 0)") or 
        &R2db::dblog("ошибка. Не удалось сохранить месячные начальные счетчики для пользователя $login.");
      $login = uri_escape($login);
      print $q->redirect("adm.cgi#$login");
    } else {
      my $err = $DBI::errstr;
      &R2db::dblog("ошибка при добавлении пользователя $login, $err.");
      &R2utils::print_start_hdr;
      print "<p>Ошибка при добавлении пользователя!</p><p>$err</p>";
      &R2utils::print_end_hdr;
    }
  } else {
    &R2utils::print_start_hdr;
    print "<p>Ошибка при добавлении пользователя!</p><p>Вы не заполнили необходимые поля или указали неверный формат.</p>";
    &R2utils::print_end_hdr;
  }
}


sub edituser {
  my $l = shift;
  my $lurl = uri_escape($l);
  if ($l) {
    # get data
    my ($login, $desc, $email_notify, $ip, $dbmac, $rt, $defjump, $speed_in, $speed_out, $no_dhcp, $qs, $limit_in) = $dbh_inet->selectrow_array("SELECT login, clients.desc, email_notify, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, qs, limit_in \
FROM clients WHERE login = " . $dbh_inet->quote($l));
    $login = CGI::escapeHTML($login);
    $desc = CGI::escapeHTML(decode_utf8($desc));
    my $ipo = NetAddr::IP->new($ip);
    $ip = CGI::escapeHTML(($ipo)?$ipo->addr:'');
    my $maco = eval { NetAddr::MAC->new($dbmac) };
    my $mac = ($maco) ? $maco->as_microsoft : '';
    $mac = CGI::escapeHTML($mac);
    # rt, defjump, qs - not needed
    # extract speed settings
    my $speed_name = 'userdef';
    my $speed_userdef_in = '';
    my $speed_userdef_out = '';
    while (my ($key, $ref) = each %speed_plans) {
      if ($speed_in eq $ref->[1] && $speed_out eq $ref->[2]) {
	$speed_name = $key; #don't exit loop here
      }
    }
    if ($speed_name eq 'userdef') {
      $speed_userdef_in = $speed_in;
      $speed_userdef_out = $speed_out;
    }

    $limit_in = CGI::escapeHTML(&R2utils::btomb($limit_in));

    &R2utils::print_start_hdr;
    print $q->h2("Редактирование пользователя ".CGI::escapeHTML($l));
    print <<HTML_FORM;
<form action="adm.cgi?edit=$lurl" method="POST">
<table>
<tr><td>Логин:</td><td><input type="text" name="login" value="$login" size="30" maxlength="30"></td><td>Логин пользователя в AD</td></tr>
HTML_FORM
    print '<tr><td>Комментарий:</td><td><input type="text" name="desc" value="';
    binmode STDOUT, ':utf8'; print $desc; binmode STDOUT;
    print '" size="50" maxlength="255"></td><td>Дополнительная информация, #заявки (пользователям не видно)</td></tr>';
    print <<HTML_FORM;
<tr><td>IP:</td><td><input type="text" name="ip" value="$ip" maxlength="30"></td><td>IPv4 (xxx.xxx.xxx.xxx)</td></tr>
<tr><td>mac:</td><td><input type="text" name="mac" value="$mac" size="30" maxlength="30"></td><td>Eui-48 ethernet MAC (xx:xx:xx:xx:xx:xx)</td></tr>
HTML_FORM
    &print_nodhcp_field($no_dhcp);
    &print_rt_field($rt);
    &print_defjump_field($defjump);
    &print_speed_fields($speed_name, $speed_userdef_in, $speed_userdef_out);
    &print_quota_fields($qs, $limit_in, $email_notify);
    print <<HTML_FORM;
</table>
<p>**&nbsp;Редактирование лимита НЕ сбрасывает счетчик оставшегося лимита для клиента. Новое значение лимита будет использовано с нового месяца.<br/>
Если необходимо изменить только лимит пользователя или режим квотировщика, используйте ссылку "Изменить лимит" в списке пользователей.<br/>
Редактирование лимитов в данном окне вызовет пересинхронизацию правил пользователя на маршрутизаторах и DHCP-сервере.</p>
<p>Применение изменений произойдет в течение 30 мин. См. значок синхронизации маршрутизаторов и DHCP в списке пользователей.<br/>
Если изменялся IP или mac клиента, то по завершении синхронизации необходимо выполнить ipconfig /release, ipconfig /renew на компьютере клиента.</p>
<p><input type="submit" name="submit_edit" value="Изменить пользователя">
<input type="button" value="Отмена" onclick="window.location.replace('adm.cgi#$lurl')"></p>
</form>
HTML_FORM
    &R2utils::print_end_hdr;
  } else {
    &R2utils::print_bad_query;
  }
}


sub edituser_submit {
  my $l = shift;
  if ($l) {
    my ($login, $desc, $ip, $mac, $rt, $defjump, $speed, $speed_userdef_in, $speed_userdef_out, $qs, $limit) = (
      $q->param('login'),
      $q->param('desc'),
      $q->param('ip'),
      $q->param('mac'),
      $q->param('rt'),
      $q->param('defjump'),
      $q->param('speed'),
      $q->param('speed_userdef_in'),
      $q->param('speed_userdef_out'),
      $q->param('qs'),
      $q->param('limit'),
    );
    my $email_notify = $q->param('email_notify');
    my $nodhcp = $q->param('nodhcp');
    my $maco = eval { NetAddr::MAC->new($mac) };

    if ($login && $ip && $mac && $maco && defined($rt) && $defjump && (my $ipo = NetAddr::IP->new($ip)) && $speed && defined($qs) && defined($limit)) {
      # format speed value
      if ($speed ne 'userdef') {
	$speed_userdef_in = $speed_plans{$speed}->[1];
	$speed_userdef_out = $speed_plans{$speed}->[2];
      }
      $speed_userdef_in = '' unless $speed_userdef_in; #if not in %speed_plans
      $speed_userdef_out = $speed_userdef_in unless $speed_userdef_out;

      my $limit_bytes = &R2utils::mbtob($limit);
      my $qlogin = $dbh_inet->quote($login);
      my $ql = $dbh_inet->quote($l);
      # update record
      my $sql = sprintf "UPDATE clients \
SET login = %s, clients.desc = %s, email_notify = %s, ip = %s, mac = %s, rt = %s, defjump = %s, speed_in = %s, speed_out = %s, no_dhcp = %s, qs = %s, limit_in = %s \
WHERE login = %s",
      $qlogin,
      $dbh_inet->quote($desc),
      ($email_notify) ? '1' : '0',
      $dbh_inet->quote($ipo->numeric),
      $dbh_inet->quote($maco->as_microsoft),
      $dbh_inet->quote($rt),
      $dbh_inet->quote($defjump),
      $dbh_inet->quote($speed_userdef_in),
      $dbh_inet->quote($speed_userdef_out),
      ($nodhcp) ? '1' : '0',
      $dbh_inet->quote($qs),
      $dbh_inet->quote($limit_bytes),
      $ql;
      if ($dbh_inet->do($sql)) { #success?
        &R2db::dblog("редактирование пользователя $login, $ip, провайдер $rt_names{$rt}, режим квоты $qs_names{$qs}.");
	# mark client for syncronization
	$dbh_inet->do("UPDATE clients_sync SET login = $qlogin, sync_rt = '1', sync_fw = '1', sync_dhcp = '1' WHERE login = $ql") or
	  &R2db::dblog("ошибка. Невозможно пометить пользователя $login для синхронизации.");
        $login = uri_escape($login);
	print $q->redirect("adm.cgi#$login");
      } else {
	my $err = $DBI::errstr;
        &R2db::dblog("ошибка при редактировании пользователя $login, $err.");
	&R2utils::print_start_hdr;
	print "<p>Ошибка при изменении данных пользователя!</p><p>$err</p>";
	&R2utils::print_end_hdr;
      }
    } else {
      &R2utils::print_start_hdr;
      print "<p>Ошибка при изменении данных пользователя!</p><p>Вы не заполнили необходимые поля или указали неверный формат.</p>";
      &R2utils::print_end_hdr;
    }
  }
}


sub deluser {
  my $l = shift;
  if ($l) {
    my $ql = $dbh_inet->quote($l);
    # delete record from clients table
    my $sql = "DELETE FROM clients WHERE login = $ql";
    if ($dbh_inet->do($sql)) { #success?
      &R2db::dblog("удаление пользователя $l.");
      # delete record from clients_sync table
      $sql = "DELETE FROM clients_sync WHERE login = $ql";
      if (!$dbh_inet->do($sql)) {
        my $err = $DBI::errstr;
        &R2db::dblog("ошибка при удалении из таблицы clients_sync $l, $err.");
      }
      print $q->redirect("adm.cgi");
    } else {
      my $err = $DBI::errstr;
      &R2db::dblog("ошибка при удалении пользователя $l, $err.");
      &R2utils::print_start_hdr;
      print "<p>Ошибка при удалении пользователя!</p><p>$err</p>";
      &R2utils::print_end_hdr;
    }
  }
}


sub edituserlimit {
  my $l = shift;
  my $lurl = uri_escape($l);
  if ($l) {
    # get data
    my ($email_notify, $qs, $limit_in, $sum_limit_in) = $dbh_inet->selectrow_array("SELECT email_notify, qs, limit_in, sum_limit_in \
FROM clients WHERE login = " . $dbh_inet->quote($l));
    # qs - no need to escape
    $limit_in = CGI::escapeHTML(&R2utils::btomb($limit_in));
    $sum_limit_in = CGI::escapeHTML(&R2utils::btomb($sum_limit_in));

    &R2utils::print_start_hdr;
    print $q->h2("Изменение лимита пользователя ".CGI::escapeHTML($l));
    print <<HTML_FORM;
<form action="adm.cgi?editlimit=$lurl" method="POST">
<p>Текущий лимит: $limit_in Мб, осталось: $sum_limit_in Мб.</p>
<table>
HTML_FORM
    &print_quota_fields($qs, $limit_in, $email_notify);
    print <<HTML_FORM;
<tr><td></td><td><input type="checkbox" name="resetsum" CHECKED>Сбросить счетчик лимита*</td><td>*&nbsp;Начать отсчет нового лимита немедленно. Иначе, новый лимит будет использован только с нового месяца.</td></tr>
<tr><td></td><td><input type="checkbox" name="addsum">Добавить временно** (см.значение &quot;осталось&quot;)</td><td>**&nbsp;Временное добавление объема к счетчику лимита до конца текущего месяца. С нового месяца счетчик будет сброшен на текущее значение лимита для пользователя.</td></tr>
</table>
<p>Изменение лимита или режима квотировщика произойдет в течение 30 мин.<br/>
Если необходимо немедленно измененить лимит, вручную запустите скрипт синхронизации на маршрутизаторе.</p>
<p><input type="submit" name="submit_limit" value="Изменить лимит пользователя">
<input type="button" value="Отмена" onclick="window.location.replace('adm.cgi#$lurl')"></p>
</form>
HTML_FORM
    &R2utils::print_end_hdr;
  } else {
    &R2utils::print_bad_query;
  }
}


sub edituserlimit_submit {
  my $l = shift;
  if ($l) {
    my $email_notify = $q->param('email_notify');
    my $qs = $q->param('qs');
    my $limit = $q->param('limit');
    if (defined($qs) && defined($limit)) {
      my $limit_bytes = &R2utils::mbtob($limit);
      # update record
      my $sql;
      if ($q->param('addsum')) {
        $sql = sprintf "UPDATE clients SET email_notify = %s, qs = %s, sum_limit_in = sum_limit_in + %s WHERE login = %s",
        ($email_notify) ? '1' : '0',
        $dbh_inet->quote($qs),
        $dbh_inet->quote($limit_bytes),
        $dbh_inet->quote($l);
      } else {
	if ($q->param('resetsum')) {
	  $sql = sprintf "UPDATE clients SET email_notify = %s, qs = %s, limit_in = %s, sum_limit_in = %s WHERE login = %s",
          ($email_notify) ? '1' : '0',
          $dbh_inet->quote($qs),
	  $dbh_inet->quote($limit_bytes),
	  $dbh_inet->quote($limit_bytes),
	  $dbh_inet->quote($l);
	} else {
	  $sql = sprintf "UPDATE clients SET email_notify = %s, qs = %s, limit_in = %s WHERE login = %s",
          ($email_notify) ? '1' : '0',
          $dbh_inet->quote($qs),
	  $dbh_inet->quote($limit_bytes),
	  $dbh_inet->quote($l);
	}
      }
      if ($dbh_inet->do($sql)) { #success?
        if ($q->param('addsum')) {
          &R2db::dblog("временное добавление лимита пользователя $l, $limit мб, режим квоты $qs_names{$qs}.");
	} else {
          &R2db::dblog("изменение лимита пользователя $l, $limit мб, режим квоты $qs_names{$qs}.");
	}
        $l = uri_escape($l);
	print $q->redirect("adm.cgi#$l");
      } else {
	my $err = $DBI::errstr;
        &R2db::dblog("ошибка при изменении лимита пользователя $l, $err.");
	&R2utils::print_start_hdr;
	print "<p>Ошибка при изменении лимита пользователя!</p><p>$err</p>";
	&R2utils::print_end_hdr;
      }
    } else {
      &R2utils::print_start_hdr;
      print "<p>Ошибка при изменении лимита пользователя!</p><p>Вы не заполнили необходимые поля или указали неверный формат.</p>";
      &R2utils::print_end_hdr;
    }
  }
}


sub viewlog {
  my $l = shift;
  &R2utils::print_start_hdr;
  if ($l eq 'admin') {
    print $q->h2("Просмотр лога администрирования");
    my $s = $dbh_inet->prepare("SELECT timestamp, msg \
FROM log_admin ORDER BY timestamp DESC, log_id DESC LIMIT 500");
    $s->execute;
    print "<p>Показаны последние 500 записей.</p>";
    print "<pre>\n";
    while (my ($time, $msg) = $s->fetchrow_array) {
      print "$time $msg\n";
    }
    $s->finish;
    print "</pre>\n";
  } elsif ($l eq 'agent') {
    print $q->h2("Просмотр лога агентов");
    my $s = $dbh_inet->prepare("SELECT timestamp, msg \
FROM log_agents ORDER BY timestamp DESC, log_id DESC LIMIT 500");
    $s->execute;
    print "<p>Показаны последние 500 записей.</p>";
    print "<pre>\n";
    while (my ($time, $msg) = $s->fetchrow_array) {
      print "$time $msg\n";
    }
    $s->finish;
    print "</pre>\n";
  } elsif ($l eq 'oplog') {
    print $q->h2("Просмотр Oplog");
    my $s = $dbh_inet->prepare("SELECT CONCAT_WS(' ', date, CONCAT('[', subsys, ']'),  info) \
FROM op_log ORDER BY id DESC LIMIT 1000");
    $s->execute;
    print "<p>Показаны последние 1000 записей.</p>";
    print "<pre>\n";
    while (my ($msg) = $s->fetchrow_array) {
      print "$msg\n";
    }
    $s->finish;
    print "</pre>\n";
  }
  &R2utils::print_end_hdr;
}


sub userinfo {
  my $l = shift;
  my $lurl = uri_escape($l);
  if ($l) {
    &R2utils::print_start_hdr;
    print $q->h2("Информация о пользователе ".CGI::escapeHTML($l));

    print "<form action=\"adm.cgi?info=$lurl\" method=\"POST\">";
    my $user1;
    my $user2;
    my $user3;
    my $user4;
    my @ll;
    my $entry = &R2ad::lookup_ad($l);
    if ($entry) {
      my %h;
      foreach (qw (cn sn givenname title mail physicaldeliveryofficename telephonenumber company)) {
	my $v = $entry->get_value($_);
	$v = '' unless $v;
	$h{$_} = CGI::escapeHTML(decode_utf8($v));
      }
      push @ll, $h{'sn'} if $h{'sn'};
      push @ll, $h{'givenname'} if $h{'givenname'};
      push @ll, "($h{'cn'})" if $h{'cn'};
      $user1 = '<b>'.join(' ', @ll).'</b>' if @ll;

      @ll = ();
      push @ll, $h{'title'} if $h{'title'};
      push @ll, $h{'company'} if $h{'company'};
      $user2 = join(', ', @ll) if @ll;

      @ll = ();
      push @ll, decode_utf8('К.').$h{'physicaldeliveryofficename'} if $h{'physicaldeliveryofficename'};
      push @ll, decode_utf8('т.').$h{'telephonenumber'} if $h{'telephonenumber'};
      $user3 = join(', ', @ll) if @ll;

      $user4 = decode_utf8("<a href=\"mailto:$h{'mail'}\">").$h{'mail'}.'</a>' if $h{'mail'};
    } else {
      $user1 = decode_utf8('Информация о пользователе недоступна');
    }
    binmode STDOUT, ':utf8'; 
    print "<p>$user1</p>" if $user1;

    print '<table>';
    print '<tr><td>', decode_utf8('Должность:'), '</td><td colspan="2">', $user2, '</td></tr>' if $user2;
    print '<tr><td>', decode_utf8('Контакты:'), '</td><td>', $user3, '</td><td></td></tr>' if $user3;
    print '<tr><td>', decode_utf8('Email:'), '</td><td>', $user4, '</td><td></td></tr>' if $user4;
    binmode STDOUT;

    # get data
    my ($login, $desc, $email_notify, $create_time, $bot, $ip, $dbmac, $rt, $defjump, $speed_in, $speed_out, $no_dhcp, $qs, $limit_in, $sum_limit_in, $sync_rt, $sync_fw, $sync_dhcp, $email_notified) = $dbh_inet->selectrow_array("SELECT clients.login, clients.desc, email_notify, create_time, bot, ip, mac, rt, defjump, speed_in, speed_out, no_dhcp, qs, limit_in, sum_limit_in, s.sync_rt, s.sync_fw, s.sync_dhcp, s.email_notified \
FROM clients, clients_sync s WHERE clients.login = " . $dbh_inet->quote($l) . " AND clients.login = s.login");
    $login = CGI::escapeHTML($login);
    $desc = CGI::escapeHTML(decode_utf8($desc));
    my $ipo = NetAddr::IP->new($ip);
    $ip = CGI::escapeHTML(($ipo)?$ipo->addr:'');
    my $maco = eval { NetAddr::MAC->new($dbmac) };
    my $mac = ($maco) ? $maco->as_microsoft : '';
    $mac = CGI::escapeHTML($mac);
    $defjump = CGI::escapeHTML($defjump);

    print "<tr><td>Комментарий:</td><td>";
    binmode STDOUT, ':utf8'; print $desc; binmode STDOUT;
    print "</td><td>(не виден пользователям)</td></tr>";

    print "<tr><td>Дата подключения:</td><td>";
    if ($create_time) { print $create_time; } else { print "Нет данных"; }
    print "</td><td></td></tr>";

    print "<tr><td><br></td></tr>";
    print "<tr><td colspan=\"2\"><b>Сетевая информация</b>&nbsp(<a href=\"adm.cgi?edit=$lurl\">редактировать пользователя</a>)</td></tr>";
    my $static_img = ($no_dhcp) ? '<img src="img/static.png" width="16" height="16" title="Клиент не использует DHCP (VPN или статический адрес)">-статика':'';
    print "<tr><td>IP:</td><td>$ip&nbsp;$static_img</td><td></td></tr>";
    print "<tr><td>mac:</td><td>$mac</td><td></td></tr>";
    print "<tr><td>Провайдер:</td><td>";
    binmode STDOUT, ':utf8'; print CGI::escapeHTML(decode_utf8($rt_names{$rt})); binmode STDOUT;
    print "</td><td>Маршрутизация для клиента.</td></tr>";
    print "<tr><td>Правило:</td><td>";
    binmode STDOUT, ':utf8'; print CGI::escapeHTML(decode_utf8($defjump_names{$defjump})); binmode STDOUT;
    print "</td><td></td></tr>";

    # extract speed settings
    my $speed_name = 'userdef';
    while (my ($key, $ref) = each %speed_plans) {
      if ($speed_in eq $ref->[1] && $speed_out eq $ref->[2]) {
	$speed_name = $key; #don't exit loop here
      }
    }
    my $speed_title = ($speed_name eq 'userdef') ? "Индивидуал:\nвходящая: $speed_in\nисходящая: $speed_out" : $speed_names{$speed_name};
    my $speed_img = "<img class=\"db\" src=\"img/speed$speed_name.png\" title=\"$speed_title\">";
    print "<tr><td>Скорость:</td><td>";
    binmode STDOUT, ':utf8'; print CGI::escapeHTML(decode_utf8($speed_names{$speed_name})); binmode STDOUT;
    print "&nbsp;$speed_img</td><td></td></tr>";
    print "<tr><td>&nbsp;&nbsp;входящая:</td><td>", CGI::escapeHTML($speed_in), "</td><td></td></tr>";
    print "<tr><td>&nbsp;&nbsp;исходящая:</td><td>",CGI::escapeHTML($speed_out),"</td><td></td></tr>";

    print "<tr><td>Режим&nbsp;квоты:</td><td>";
    binmode STDOUT, ':utf8'; print CGI::escapeHTML(decode_utf8($qs_names{$qs})); binmode STDOUT;
    print "</td><td>Метод работы квотировщика.</td></tr>";

    my $blocked_img = ($sum_limit_in <= 0) ? &get_blocked_img($qs).'-*квота*' : '';
    print "<tr><td>Лимит:</td><td colspan=\"2\">", &R2utils::btomb($limit_in), " Мб (Осталось: ", &R2utils::btomb($sum_limit_in)," Мб)&nbsp;$blocked_img&nbsp(<a href=\"rep.cgi?user=$lurl\">отчёт по трафику</a>, <a href=\"adm.cgi?editlimit=$lurl\">изменить лимит</a>)</td></tr>";
    if ($email_notify) {
      print '<tr><td></td><td><img src="img/mail-notify.png" width="16" height="16">&nbsp;Включено оповещение пользователя по e-mail при окончании лимита.</td></tr>';
    } else {
      print '<tr><td></td><td style="color:#b0b0b0">Оповещение пользователя по e-mail при окончании лимита отключено.</td></tr>';
    }

    print "<tr><td><br></td></tr>";
    print "<tr><td colspan=\"2\"><b>Системная информация</b>&nbsp;<input type=\"submit\" name=\"submit_info\" value=\"Сохранить изменения\"></td><td>Несанкционированное изменение может привести к рассинхронизации оборудования!</td></tr>";

    print "<tr><td colspan=\"2\">Флаги синхронизации:</td><td></td></tr>";
    print "<tr><td></td><td>", $q->checkbox(-name => "sync_rt",
      -checked => ($sync_rt) ? 1 : 0,
      -label => 'Router'
    ), "</td><td></td></tr>";
    print "<tr><td></td><td>", $q->checkbox(-name => "sync_fw",
      -checked => ($sync_fw) ? 1 : 0,
      -label => 'Firewall/Limiter'
    ), "</td><td></td></tr>";
    print "<tr><td></td><td>", $q->checkbox(-name => "sync_dhcp",
      -checked => ($sync_dhcp) ? 1 : 0,
      -label => 'DHCP Servers'
    ), "</td><td></td></tr>";

    print "<tr><td colspan=\"2\">Флаг уведомления:</td><td></td></tr>";
    print "<tr><td></td><td>", $q->checkbox(-name => "email_notified",
      -checked => ($email_notified) ? 1 : 0,
      -label => 'Состояние уведомления'
    ), "</td><td></td></tr>";

    print "<tr><td colspan=\"2\">Бот флаг (для учеток-компьютеров):</td><td></td></tr>";
    print "<tr><td></td><td>", $q->checkbox(-name => "bot",
      -checked => ($bot) ? 1 : 0,
      -label => 'Не включать в отчет по пользователям'
    ), "</td><td></td></tr>";

    print <<HTML_FORM;
</table>
<p><input type="button" value="Вернуться к списку пользователей" onclick="window.location.replace('adm.cgi#$lurl')">
</p>
</form>
HTML_FORM
    &R2utils::print_end_hdr;
  } else {
    &R2utils::print_bad_query;
  }
}


sub userinfo_submit {
  my $l = shift;
  if ($l) {
    my $sync_rt = $q->param('sync_rt');
    my $sync_fw = $q->param('sync_fw');
    my $sync_dhcp = $q->param('sync_dhcp');
    my $email_notified = $q->param('email_notified');
    my $bot = $q->param('bot');
    # update record
    my $sql = sprintf "UPDATE clients_sync SET sync_rt = %s, sync_fw = %s, sync_dhcp = %s, email_notified = %s WHERE login = %s",
      ($sync_rt) ? '1' : '0',
      ($sync_fw) ? '1' : '0',
      ($sync_dhcp) ? '1' : '0',
      ($email_notified) ? '1' : '0',
      $dbh_inet->quote($l);
    my $sql2 = sprintf "UPDATE clients SET bot = %s WHERE login = %s", 
      ($bot) ? '1' : '0',
      $dbh_inet->quote($l);
    if ($dbh_inet->do($sql) && $dbh_inet->do($sql2)) { #success?
      &R2db::dblog("ручное изменение флагов пользователя $l.");
      $l = uri_escape($l);
      print $q->redirect("adm.cgi?info=$l");
    } else {
      my $err = $DBI::errstr;
      &R2db::dblog("ошибка при ручном изменении флагов пользователя $l, $err.");
      &R2utils::print_start_hdr;
      print "<p>Ошибка при ручном изменении флагов пользователя!</p><p>$err</p>";
      &R2utils::print_end_hdr;
    }
  }
}
