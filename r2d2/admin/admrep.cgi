#!/usr/bin/perl -T
# This is the part of R2D2
# Administrator Reports
# author: Ural Khassanov, 2013
#

use lib '..';
require 'r2db.pm';
require 'r2ad.pm';
require 'r2utils.pm';

use strict;
use warnings;
use Encode;
use NetAddr::IP;
use NetAddr::MAC;
use URI::Escape;
#no warnings 'uninitialized';
use Date::Simple ('today');
use GD::Graph::pie;
#use warnings 'all';

&R2utils::set_modname('admrep');
&R2utils::set_footername('Административные отчеты');
&R2utils::set_title('Административные отчеты');

my ($chart_dx, $chart_dy) = (400, 300);

my $q = &R2utils::cgi; # set short name to query object

&R2db::open_dbs();

###
# parameters switch
my $kk = $q->param('type');
if ($kk && &R2utils::is_admin) {
  if ($kk eq 'macdup') {
    &report_macdup;
  } elsif ($kk eq 'leech') {
    my $mm = $q->param('month');
    if ($mm) {
      &report_leech($mm eq 'prev');
    } else {
      &report_leech;
    }
  } elsif ($kk eq 'leechchart') {
    my $mm = $q->param('month');
    if ($mm) {
      &leech_chart($mm eq 'prev');
    } else {
      &leech_chart;
    }
  } elsif ($kk eq 'users') {
    &report_users;
  } else {
    &R2utils::print_bad_query;
  }
} else {
  &R2utils::print_bad_query;
}

&R2db::close_dbs();

exit;

###
sub report_macdup {
  my $t = 'Отчет по дубликатам mac';
  &R2utils::set_title($t);
  &R2utils::print_start_hdr;
  print $q->h2($t);

  my $s = &R2db::dbh_inet->prepare("SELECT login, ip, mac, no_dhcp \
FROM clients ORDER BY ip ASC");
  $s->execute;

  my %mac_hash;
  my $i = 1;
  while (my ($login, $dbip, $dbmac, $no_dhcp) = $s->fetchrow_array) {
    my $ip = NetAddr::IP->new($dbip);
    my $maco = eval { NetAddr::MAC->new($dbmac) };
    my $mac = ($maco) ? $maco->as_microsoft : '';

    if ($mac eq '' || $mac_hash{$mac}) {
      my $static_img;
      my $info = 'Ошибка. Наличие дубликатов mac приведет к некорректной работе DHCP.';
      my $td_style = 'background:#ffeac2;color:#ff0000';
      if ($i == 1) {
	print "<p>В базе данных имеются неверные или дублирующиеся mac-адреса:</p>";
        print "<table class=\"db\"><tr><th></th><th>mac</th><th>IP</th><th>Логин</th><th>Информация</th></tr>\n";
        &print_macdup_line($i, $mac, $mac_hash{$mac});
	$i++;
      }
      &print_macdup_line($i, $mac, [ $ip, $login, $no_dhcp ]);
      $i++;
    } else {
      $mac_hash{$mac} = [ $ip, $login, $no_dhcp ];
    }
  }
  $s->finish;
  if ($i > 1) {
    print "</table>\n";
  } else {
    print "<p>В базе данных дублирующихся mac-адресов не обнаружено.</p>";
  }
  &R2utils::print_end_hdr;
}

# &print_macdup_line($i, $mac, [ $ip, $login, $no_dhcp ])
sub print_macdup_line {
  my $i = shift;
  my $mac = shift;
  my $aref = shift;
  my $_ip = $aref->[0];
  my $_login = $aref->[1];
  my $_no_dhcp = $aref->[2];

  my $info;
  my $td_style;
      
  print "<tr><td>$i</td>";
  print "<td>",CGI::escapeHTML($mac),"</td>";
  print "<td>",($_ip)?$_ip->addr:'---',"</td>";
  my $static_img = ($_no_dhcp) ? '<img src="img/static.png" width="16" height="16" title="Клиент не использует DHCP (VPN или статический адрес)">':'';
  print "<td>",CGI::escapeHTML($_login),$static_img,"</td>";
  if ($mac eq '') {
    $info = 'Ошибка. Некорректный mac адрес, обработка клиента будет заблокирована.';
    $td_style = 'background:#ffeac2;color:#ff0000';
  } elsif ($_no_dhcp) {
    $info = 'Допустимо для VPN клиентов. Клиент не использует DHCP.';
    $td_style = 'background:#b3ffb2;color:#00a300';
  } else {
    $info = 'Ошибка. Наличие дубликатов mac приведет к некорректной работе DHCP.';
    $td_style = 'background:#ffeac2;color:#ff0000';
  }
  print "<td style=\"$td_style\">$info</td>";
}


# &report_leech(prevmonth=0/1)
sub report_leech {
  my $prevmonth = shift;
  my $t = 'ТОП пользователей по объему входящего трафика';
  &R2utils::set_title($t);
  &R2utils::print_start_hdr;
  print $q->h2($t);

  my $dlref = ($prevmonth) ? &get_prev_month_data(0) : &get_cur_month_data(0);
  #print $_->[0],' ',$_->[1],' ',$_->[2],' ',$_->[3],"<br>\n" foreach (@$dlref);
  #print "$_ " foreach (@{$dlref->[0]}); print "<br>"; print "$_ " foreach (@{$dlref->[1]}); print "<br>";
  my $i = 1;
  my $sum_total_in = 0;
  my $sum_total_out = 0;
  my $tbl = '';
  foreach (@$dlref) {
    my $l = $_->[0];
    my $ul = uri_escape($l);
    $tbl .= "<tr><td>$i</td><td><a href=\"rep.cgi?user=$ul\">".CGI::escapeHTML($l)."</a></td><td>".$_->[1]."</td><td>".&R2utils::btomb($_->[2])." Мб </td><td>".&R2utils::btomb($_->[3])." Мб </td></tr>";
    $sum_total_in += $_->[2];
    $sum_total_out += $_->[3];
    $i++;
  }
  if ($prevmonth) {
    print "<p>Данные за предыдущий месяц. <a href=\"admrep.cgi?type=leech\">Просмотреть отчёт за текущий месяц.</a><br>";
  } else {
    print "<p>Данные за текущий месяц. <a href=\"admrep.cgi?type=leech&month=prev\">Просмотреть отчёт за предыдущий месяц.</a><br>";
  }
  print "Всего получено: ", &R2utils::btomb($sum_total_in), " Мб, отправлено: ", &R2utils::btomb($sum_total_out)," Мб.</p>";
  my $chart_month = ($prevmonth) ? '&month=prev' : '';
  print "<p><img src=\"admrep.cgi?type=leechchart$chart_month\" width=\"$chart_dx\" height=\"$chart_dy\"></p>";
  print "<table class=\"db\"><tr><th>N</th><th>Логин</th><th>IP</th><th>Получено</th><th>Отправлено</th></tr>\n";
  print $tbl;
  print "</table>\n";
  &R2utils::print_end_hdr;
}


# &leech_chart(prevmonth=0/1)
sub leech_chart {
  my $prevmonth = shift;
  my $g = new GD::Graph::pie($chart_dx, $chart_dy);
  my $dref = ($prevmonth) ? &get_prev_month_data(1) : &get_cur_month_data(1);

  $g->set(
    '3d' => 1,
    label=>'ТОП 15 по объему входящего трафика',
    #dclrs => [ '#ba4d51', '#af8a53', '#955f71', '#859666', '#5f8b95' ],
    #dclrs => [ '#75b5d6', '#b78c9b', '#f2ca84', '#7cbab4', '#92c7e2' ],
    dclrs => [ '#ba4d51', '#ad79ce', '#a6c567', '#e18e92', '#fcb65e', '#679ec5', '#b78c9b', '#f2ca84', '#7cbab4', '#92c7e2', '#859666' ],
  );
  $g->set_label_font('/etc/r2d2/arial.ttf', 10);
  $g->set_value_font('/etc/r2d2/arial.ttf', 9);
  my $gd_image = $g->plot($dref);
  print $q->header(-type => 'image/png', -expires => '-1d');
  binmode STDOUT;
  print $gd_image->png;
}


# &get_cur_month_data(graphmode=0/1)
sub get_cur_month_data {
  my $graphmode = shift;
  my @datalist;

  # load data
  my $today = &R2db::dbh_inet->quote(today()->as_iso);
  my $firstday = &R2db::dbh_inet->quote(Date::Simple::ymd(today()->year, today()->month, 1)->as_iso); #YYYY-MM-01
  my $s = &R2db::dbh_inet->prepare("SELECT login, ip, sum_in, sum_out \
FROM clients ORDER BY ip ASC");
  $s->execute;

  while (my ($login, $dbip, $sum_in, $sum_out) = $s->fetchrow_array) {
    my $ip = NetAddr::IP->new($dbip);
    my $ql = &R2db::dbh_inet->quote($login);

    # current month data
    my @b = &R2db::dbh_inet->selectrow_array("SELECT m_in, m_out \
FROM amonthly WHERE login = $ql AND date <= $today AND date >= $firstday \
ORDER BY date ASC");
    if (@b) {
      my $r_in = $sum_in - $b[0];
      $r_in = $sum_in if ($r_in < 0);
      my $r_out = $sum_out - $b[1];
      $r_out = $sum_out if ($r_out < 0);
      push @datalist, [$login, $ip->addr, $r_in, $r_out];
    }
  }
  $s->finish;
  #print $_->[0],' ',$_->[1],' ',$_->[2],' ',$_->[3],"<br>\n" foreach (@datalist);

  # sort list
  my @sl = sort { $b->[2] <=> $a->[2] } @datalist;

  # graphmode processing
  if ($graphmode) {
    my @ll;
    my @inl;
    my $i = 0;
    my $sum_oth = 0;
    foreach (@sl) {
      if ($i < 15) {
        push @ll, $_->[0]; #login
	push @inl, $_->[2]; #r_in
      } else {
        $sum_oth += $_->[2];
      }
      $i++;
    }
    push @ll, 'Остальные';
    push @inl, $sum_oth;
    return [ \@ll, \@inl ];
  } else {
    return \@sl;
  }
}

# &get_prev_month_data(graphmode=0/1)
sub get_prev_month_data {
  my $graphmode = shift;
  my @datalist;

  # load data
  my $firstday = &R2db::dbh_inet->quote(Date::Simple::ymd(today()->year, today()->month, 1)->as_iso); #YYYY-MM-01
  my $s = &R2db::dbh_inet->prepare("SELECT login, ip \
FROM clients ORDER BY ip ASC");
  $s->execute;

  while (my ($login, $dbip) = $s->fetchrow_array) {
    my $ip = NetAddr::IP->new($dbip);
    my $ql = &R2db::dbh_inet->quote($login);

    # previous month data
    my $s1 = &R2db::dbh_inet->prepare("SELECT m_in, m_out \
FROM amonthly WHERE login = $ql AND date <= $firstday AND date >= DATE_SUB($firstday, INTERVAL 1 MONTH) \
ORDER BY date DESC");
    $s1->execute;
    my ($m_in, $m_out);
    my ($r_in, $r_out);
    my $rr = $s1->rows;
    my @l = $s1->fetchrow_array;
    if (@l) {
      ($r_in, $r_out) = @l;
      while (@l = $s1->fetchrow_array) { # skip records
        ($m_in, $m_out) = @l;
      }
      if ($rr > 1) {
        $r_in -= $m_in if ($r_in >= $m_in);
        $r_out -= $m_out if ($r_out >= $m_out);
      }
      push @datalist, [$login, $ip->addr, $r_in, $r_out];
    }
    $s1->finish;
  }
  $s->finish;
  #print $_->[0],' ',$_->[1],' ',$_->[2],' ',$_->[3],"<br>\n" foreach (@datalist);

  # sort list
  my @sl = sort { $b->[2] <=> $a->[2] } @datalist;

  # graphmode processing
  if ($graphmode) {
    my @ll;
    my @inl;
    my $i = 0;
    my $sum_oth = 0;
    foreach (@sl) {
      if ($i < 15) {
        push @ll, $_->[0]; #login
	push @inl, $_->[2]; #r_in
      } else {
        $sum_oth += $_->[2];
      }
      $i++;
    }
    push @ll, 'Остальные';
    push @inl, $sum_oth;
    return [ \@ll, \@inl ];
  } else {
    return \@sl;
  }
}

sub report_users {
  my $t = 'Списки пользователей интернет';
  &R2utils::set_title($t);
  &R2utils::print_start_hdr;
  print $q->h2($t);

  # this duplicates adm.cgi
  my %rt_names = (
    '0' => 'Уфанет',
    '1' => 'Билайн',
  );

  foreach my $rt_code (sort keys %rt_names) {
    print '<h3>Список пользователей провайдера '.$rt_names{$rt_code}.'</h3>';
    print "<pre>\n";
    my $s = &R2db::dbh_inet->prepare("SELECT login FROM clients WHERE bot = 0 AND rt = $rt_code AND (create_time IS NULL OR create_time < NOW()) ORDER BY ip ASC");
    $s->execute;
    my $uc = 0;
    my $ucc;
    while (my ($login) = $s->fetchrow_array) {
      ###Encode::from_to($desc, 'utf-8', 'koi8-r');
      my $ucc = $uc + 1;
      my $entry = &R2ad::lookup_ad($login);
      if ($entry) {
	#foreach (qw (cn sn givenname title)) {
	my $cn = $entry->get_value('cn');
	$cn = '' unless $cn;
	my $title = $entry->get_value('title');
	$title = '' unless $title;
	my $k = $entry->get_value('physicaldeliveryofficename');
	$k = '' unless $k;
	# hope there no tags in data...
	print "$ucc, $cn, $title, К.$k\n";

      } else { print "$ucc, $login: информация о пользователе недоступна\n"; }
      $uc++;
    }

    $s->finish;
    print "\nВсего $uc пользователей.\n\n";
    print "</pre>\n";
  }
  &R2utils::print_end_hdr;
}

