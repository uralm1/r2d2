#!/usr/bin/perl -T
# This is the part of R2D2
# Report interface
# author: Ural Khassanov, 2013
#

use lib '..';
require 'r2db.pm';
require 'r2ad.pm';
require 'r2utils.pm';

use strict;
use warnings;
use DBI;
use URI::Escape;
use Encode;
no warnings 'uninitialized';
use Date::Simple ('today');
use GD::Graph::bars;
use warnings 'all';

&R2utils::set_modname('rep');
&R2utils::set_footername('Отчёты по трафику', 1);
&R2utils::set_title('Отчет по трафику для пользователя');

my $q = &R2utils::cgi; # set short name to query object

my ($graph_dx, $graph_dy) = (950, 230);
my ($graph_dx_month, $graph_dy_month) = (700, 230);

&R2db::open_dbs();
my $dbh_inet = &R2db::dbh_inet; # set short name for db handle object

###
# parameters switch
my $kk;
if (($kk = $q->url_param('user')) && $q->param('submit_user')) {
  if (&R2utils::is_admin || $kk eq &R2utils::remote_user) {
    &submit_user($kk);
  } else {
    &R2utils::print_bad_query;
  }
} else {
  $kk = $q->param('user');
  $kk = &R2utils::remote_user unless $kk; #use remote_user if user is not specified 

  my $per;
  if ($kk && (&R2utils::is_admin || $kk eq &R2utils::remote_user)) {
    if ($per = $q->param('graph')) {
      &graph($kk, $per);
    } elsif ($per = $q->param('rep')) {
      if ($per eq 'month') { &report_month($kk); } else { &report($kk); }
    } else {
      &report($kk);
    }
  } else {
    &R2utils::print_bad_query;
  }
}

&R2db::close_dbs();

exit;

###
# print &r_str(val, prevval, tilde2flag)
sub r_str {
  my $val = shift;
  my $prevval = shift;
  my $tilde2flag = shift;

  my $r = $val - $prevval;
  my $r_mb;
  if ($r < 0) { $r = "~$val"; $r_mb = '~'.&R2utils::btomb($val); } else { $r_mb = &R2utils::btomb($r); }
  if ($tilde2flag) { 
    $r = "~$r"; $r_mb = "~$r_mb";
  }
  return "$r_mb Мб ($r байт)";
}

# $v = &r_mb(val, prevval)
sub r_mb {
  my $val = shift;
  my $prevval = shift;

  my $r = $val - $prevval;
  $r = $val if ($r < 0);
  return &R2utils::btomb($r);
}

# $ok = &print_rnow_table(login)
sub print_rnow_table {
  my $l = shift;
  my $ql = $dbh_inet->quote($l);
  my @a = $dbh_inet->selectrow_array("SELECT email_notify, sum_in, sum_out, qs, limit_in, sum_limit_in \
FROM clients WHERE login = $ql");
  if (@a) {
    my $email_notify = $a[0];
    my $sum_in = $a[1];
    my $sum_out = $a[2];
    my $qs = $a[3];
    my $limit_in = $a[4];
    my $sum_limit_in = $a[5];

    my $check_img;
    my $check_text_style;
    if ($qs != 0 && $sum_limit_in <= 0) {
      if ($qs == 1) { # warn
        $check_img = '<img style="margin-right:5px" src="img/rep-warn.png" width="48" height="48" title="Лимит исчерпан. Предупреждение! Ваше потребление трафика превысило установленную норму.">';
      } elsif ($qs == 2) { # speed
        $check_img = '<img style="margin-right:5px" src="img/rep-blocked.png" width="48" height="48" title="Лимит исчерпан. Доступ в Интернет ограничен по скорости. Полные возможности будут доступны с начала нового месяца.">';
      } else { # drop
        $check_img = '<img style="margin-right:5px" src="img/rep-blocked.png" width="48" height="48" title="Лимит исчерпан. Доступ в Интернет заблокирован. Работа в сети будет возможна с начала нового месяца.">';
      }
      $check_text_style = 'style="color:#ff0000"';
    } else { # ok
      $check_img = '<img style="margin-right:5px" src="img/rep-ok.png" width="48" height="48" title="Работа без ограничений.">';
      $check_text_style = '';
    }
    $limit_in = CGI::escapeHTML(&R2utils::btomb($limit_in));
    $sum_limit_in = CGI::escapeHTML(&R2utils::btomb($sum_limit_in));
    print '<form action="rep.cgi?user=', uri_escape($l), '" method="POST">';
    print "<table><tr><td rowspan=\"3\">$check_img</td>";

    my $user1;
    my $user2;
    my $user3;
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
      $user2 = '<b>'.join(', ', @ll).'</b>' if @ll;

      @ll = ();
      push @ll, decode_utf8('к.').$h{'physicaldeliveryofficename'} if $h{'physicaldeliveryofficename'};
      push @ll, decode_utf8('т.').$h{'telephonenumber'} if $h{'telephonenumber'};
      push @ll, $h{'mail'} if $h{'mail'};
      $user3 = '<b>'.join(', ', @ll).'</b>' if @ll;
    } else {
      $user1 = decode_utf8('Информация о пользователе недоступна');
      $user2 = decode_utf8('<a href="https://otk.uwc.ufanet.ru/otrs">Обратитесь в группу сетевого администрирования.</a>');
    }
    print '<td>';
    binmode STDOUT, ':utf8'; 
    print $user1 if $user1;
    print '<br>', $user2 if $user2;
    print '<br>', $user3 if $user3;
    binmode STDOUT;
    print '</td></tr>'; 

    # print limit info only if quota enabled
    if ($qs != 0) {
      print "<tr><td>Текущий лимит: $limit_in Мб, <span $check_text_style>осталось: $sum_limit_in Мб</span>.</td></tr>";
      print '<tr><td>', $q->checkbox(-name => "email_notify",
	-checked => ($email_notify) ? 1 : 0,
	-label => 'Уведомление по e-mail об окончании лимита.'
      ), '&nbsp;<input type="submit" name="submit_user" value="Сохранить"></td></tr>';
    }
    print '</table></form><br/>';
    
    # print current day data
    my @b = $dbh_inet->selectrow_array("SELECT d_in, d_out \
FROM adaily WHERE login = $ql AND date = CURDATE()");
    print "<table class=\"db\"><tr><th>Дата: ",today()->format('%d-%m-%Y'),"</th><th>Получено</th><th>Отправлено</th></tr>";
    my ($r_in, $r_out);
    if (@b) {
      $r_in = &r_str($sum_in, $b[0], 0);
      $r_out = &r_str($sum_out, $b[1], 0);
    } else {
      $r_in = $r_out = 'н/д';
    }
    print "<tr><td>За сегодня</td><td>$r_in</td><td>$r_out</td></tr>";

    # print current month data
    my $today = $dbh_inet->quote(today()->as_iso);
    my $firstday = $dbh_inet->quote(Date::Simple::ymd(today()->year, today()->month, 1)->as_iso); #YYYY-MM-01
    @b = $dbh_inet->selectrow_array("SELECT date, m_in, m_out \
FROM amonthly WHERE login = $ql AND date <= $today AND date >= $firstday \
ORDER BY date ASC");
    if (@b) {
      my $recdate = Date::Simple->new($b[0]);
      if (!$recdate) {die "Date conversion error\n";}
      my $recday = $recdate->day;
      $r_in = &r_str($sum_in, $b[1], $recday != 1);
      $r_out = &r_str($sum_out, $b[2],  $recday != 1);
    } else {
      $r_in = $r_out = 'н/д';
    }
    print "<tr><td>В текущем месяце</td><td>$r_in</td><td>$r_out</td></tr>";
    print "</table>\n";
    return 1;
  } else {
    return 0;
  }
}


###
sub report {
  my $l = shift;
  my $lurl = uri_escape($l);
  &R2utils::print_start_hdr;
  print $q->h2("Просмотр трафика пользователя ".CGI::escapeHTML($l));

  if (&print_rnow_table($l)) {
    my $days_month = Date::Simple::days_in_month(today()->year, today()->month);

    print "<p>Ежедневные данные за последние $days_month(+1) дней. <a href=\"rep.cgi?user=$lurl&rep=month\">Просмотреть отчёт по месяцам.</a></p>";
    print "<p><img src=\"rep.cgi?user=$lurl&graph=daily\" width=\"$graph_dx\" height=\"$graph_dy\"></p>";
    print "<table class=\"db\"><tr><th>Дата</th><th>Получено (за сутки)</th><th>Отправлено (за сутки)</th></tr>\n";
    my $data = &get_daily_data($l, 0);
    #$$data[0] = \@days
    #$$data[1] = \@in
    #$$data[2] = \@out
    my $i = 0;
    foreach my $day (@{$$data[0]}) {
      print "<tr><td>$day</td><td>".$$data[1]->[$i]."</td><td>".$$data[2]->[$i]."</td></tr>";
      $i++;
    }
    print "</table>\n";
  } else {
    print "<p>Пользователь указан неверно или он не имеет права доступа к Интернет.</p>";
  }
  &R2utils::print_end_hdr;
}


sub report_month {
  my $l = shift;
  my $lurl = uri_escape($l);
  &R2utils::print_start_hdr;
  print $q->h2("Просмотр трафика пользователя ".CGI::escapeHTML($l));

  if (&print_rnow_table($l)) {
    print "<p>Ежемесячные данные за последние 12 месяцев. <a href=\"rep.cgi?user=$lurl\">Просмотреть ежедневный отчёт.</a></p>";
    print "<p><img src=\"rep.cgi?user=$lurl&graph=monthly\" width=\"$graph_dx_month\" height=\"$graph_dy_month\"></p>";
    print "<table class=\"db\"><tr><th>Месяц</th><th>Получено (за месяц)</th><th>Отправлено (за месяц)</th></tr>\n";
    my $data = &get_monthly_data($l, 0);
    #$$data[0] = \@months
    #$$data[1] = \@in
    #$$data[2] = \@out
    my $i = 0;
    foreach my $month (@{$$data[0]}) {
      print "<tr><td>$month</td><td>".$$data[1]->[$i]."</td><td>".$$data[2]->[$i]."</td></tr>";
      $i++;
    }
    print "</table>\n";
  } else {
    print "<p>Пользователь указан неверно или он не имеет права доступа к Интернет.</p>";
  }
  &R2utils::print_end_hdr;
}


sub graph {
  my $l = shift;
  my $type = shift;
  my $g;
  my $data;
  if ($type eq 'monthly') {
    $g = new GD::Graph::bars($graph_dx_month, $graph_dy_month);
    $data = &get_monthly_data($l, 1);
  } else {
    $g = new GD::Graph::bars($graph_dx, $graph_dy);
    $data = &get_daily_data($l, 1);
  }

  $g->set(
    #x_label => "Дни",
    y_label => "Мегабайты",
    long_ticks => 1,
    #y_max_value => 40,
    y_min_value => 0,
    #y_tick_number => 8,
    #y_label_skip => 2,
    bargroup_spacing => 3,
    dclrs => [ '#facd8a', '#af88b8' ],
    #shadow_depth => 2,
    #shadowclr => 'gray',
    legend_placement => 'RC',
  );
  $g->set_x_label_font('/etc/r2d2/arial.ttf', 7);
  $g->set_y_label_font('/etc/r2d2/arial.ttf', 7);
  $g->set_x_axis_font('/etc/r2d2/arial.ttf', 7);
  $g->set_y_axis_font('/etc/r2d2/arial.ttf', 7);
  $g->set_legend_font('/etc/r2d2/arial.ttf', 9);
  $g->set_legend("Получено", "Отправлено");
  my $gd_image = $g->plot($data);
  print $q->header(-type => 'image/png', -expires => '-1d');
  binmode STDOUT;
  print $gd_image->png;
}


# &get_daily_data(username, graphmode=0/1)
sub get_daily_data {
  my $l = shift;
  my $graphmode = shift;
  my $ql = $dbh_inet->quote($l);

  my @days_row;
  my @in_row;
  my @out_row;

  my $s = $dbh_inet->prepare("SELECT date, d_in, d_out \
FROM adaily WHERE login = $ql AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH) \
ORDER BY date DESC");
  $s->execute;

  my $date_fmt_graph = '%d.%m';
  my $date_fmt_text = '%d-%m-%Y %a';

  my $days_month = Date::Simple::days_in_month(today()->year, today()->month);
  my $daycount = today();
  my $dayend = today() - ($days_month + 1);
  my ($lastin, $lastout);
  my ($date, $in, $out);
  my $recdate = undef;
  $lastin = undef;
  my $startflag = 1;
  my $endflag = 0;

  while($daycount >= $dayend) {
    if (!$endflag) {
      if (!$recdate) {
	if (($date, $in, $out) = $s->fetchrow_array) {
	  $recdate = Date::Simple->new($date);
	  if (!$recdate) {die "Date conversion error\n";}
	} else {
	  $endflag = 1;
	}
      }
    }

    if ($daycount == $recdate) {
      if (defined($lastin)) {
	if ($graphmode) {
          push @days_row, $daycount->format($date_fmt_graph);
	  push @in_row, &r_mb($lastin, $in);
	  push @out_row, &r_mb($lastout, $out);
	} else {
          push @days_row, $daycount->format($date_fmt_text);
	  push @in_row, &r_str($lastin, $in, 0);
	  push @out_row, &r_str($lastout, $out, 0);
	}
      } else {
	if (!$startflag) {
	  if ($graphmode) {
	    push @days_row, $daycount->format($date_fmt_graph);
	    push @in_row, undef;
	    push @out_row, undef;
	  } else {
            push @days_row, $daycount->format($date_fmt_text);
	    push @in_row, 'н/д';
	    push @out_row, 'н/д';
	  }
	} else { $startflag = 0; }
      }
      $lastin = $in; $lastout = $out;
      $recdate = undef;
    } else {
      if (!$startflag) {
	if ($graphmode) {
	  push @days_row, $daycount->format($date_fmt_graph);
	  push @in_row, undef;
	  push @out_row, undef;
	} else {
          push @days_row, $daycount->format($date_fmt_text);
	  push @in_row, 'н/д';
	  push @out_row, 'н/д';
	}
      } else { $startflag = 0; }
      $lastin = undef;
    }
    $daycount--;
  }
  $s->finish;
  return [ \@days_row, \@in_row, \@out_row ];
}


# &get_monthly_data(username, graphmode=0/1)
sub get_monthly_data {
  my $l = shift;
  my $graphmode = shift;
  my $ql = $dbh_inet->quote($l);

  my @months_row;
  my @in_row;
  my @out_row;

  my $s = $dbh_inet->prepare("SELECT date, m_in, m_out \
FROM amonthly WHERE login = $ql AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) \
ORDER BY date ASC");
  $s->execute;
  my @months;
  my @ins;
  my @outs;
  my ($lastyear, $lastmonth, $lastday) = (undef, undef, undef);
  while (my ($date, $in, $out) = $s->fetchrow_array) {
    my $recdate = Date::Simple->new($date);
    if (!$recdate) {die "Date conversion error\n";}
    my ($year, $month, $day) = $recdate->as_ymd;

    if (defined($lastday)) {
      if ($month == $lastmonth && $year == $lastyear) {
        next; #skip the same month, but different dates
      }
    }
    ($lastyear, $lastmonth, $lastday) = ($year, $month, $day);
    push @months, $recdate;
    push @ins, $in;
    push @outs, $out;
  }
  $s->finish;

  #for (my $i = $#months; $i >= 0; $i--) {
  #  push @months_row, $months[$i];
  #  push @in_row, $ins[$i];
  #  push @out_row, $outs[$i];
  #}

  my $date_fmt_graph = '%b.%y';
  my $date_fmt_text = '%b %m-%Y';

  my $daycount = Date::Simple::ymd(today()->year, today()->month, 1); #YYYY-MM-01
  my $dayend = Date::Simple::ymd(today()->year - 1, today()->month, 1); #YYYY-MM-01
  my ($lastin, $lastout);
  my ($date, $in, $out);
  my $recdate = undef;
  my ($recday, $recmonth, $recyear);
  $lastin = undef;
  my $startflag = 1;
  my $endflag = 0;
  my $lastroundflag = 0;

  my $i = $#months; #array index from last to first
  while($daycount >= $dayend) {
    my $rep_month = $daycount->month - 1;
    my $rep_year = $daycount->year;
    if ($rep_month < 1) { $rep_month = 12; $rep_year--; }
    my $days_rep_month = Date::Simple::days_in_month($rep_year, $rep_month);

    if (!$endflag) {
      if (!$recdate) {
	if ($i >= 0) {
	  ($recdate, $in, $out) = ($months[$i], $ins[$i], $outs[$i]); 
	  #my $recdate = Date::Simple->new($date);
	  #if (!$recdate) {die "Date conversion error\n";}
	  $recday = $recdate->day;
	  $recmonth = $recdate->month;
	  $recyear = $recdate->year;
	  $i--;
	} else {
	  $endflag = 1;
	}
      }
    }
    
    if (!$endflag && $daycount->month == $recmonth && $daycount->year == $recyear) {
      if (defined($lastin)) {
	if ($graphmode) {
          push @months_row, $daycount->format($date_fmt_graph);
	  push @in_row, &r_mb($lastin, $in);
	  push @out_row, &r_mb($lastout, $out);
	} else {
          push @months_row, $daycount->format($date_fmt_text);
	  push @in_row, &r_str($lastin, $in, ($lastroundflag || $recday != 1));
	  push @out_row, &r_str($lastout, $out, ($lastroundflag || $recday != 1));
	}
      } else {
	if (!$startflag) {
	  if ($graphmode) {
	    push @months_row, $daycount->format($date_fmt_graph);
	    push @in_row, undef;
	    push @out_row, undef;
	  } else {
            push @months_row, $daycount->format($date_fmt_text);
	    push @in_row, 'н/д';
	    push @out_row, 'н/д';
	  }
	} else { $startflag = 0; }
      }
      $lastin = $in; $lastout = $out;
      $lastroundflag = ($recday != 1);
      $recdate = undef;
    } else {
      if (!$startflag) {
	if ($graphmode) {
	  push @months_row, $daycount->format($date_fmt_graph);
	  push @in_row, undef;
	  push @out_row, undef;
	} else {
          push @months_row, $daycount->format($date_fmt_text);
	  push @in_row, 'н/д';
	  push @out_row, 'н/д';
	}
      } else { $startflag = 0; }
      $lastin = undef;
      $lastroundflag = 0;
    }
    $daycount-=$days_rep_month;
  }
  return [ \@months_row, \@in_row, \@out_row ];
}


sub submit_user {
  my $l = shift;
  if ($l) {
    my $email_notify = $q->param('email_notify');
    # update record
    my $sql = sprintf "UPDATE clients SET email_notify = %s WHERE login = %s",
      ($email_notify) ? '1' : '0',
      $dbh_inet->quote($l);
    if ($dbh_inet->do($sql)) { #success?
      &R2db::dblog((($email_notify)?'в':'от')."ключение уведомления по e-mail, пользователь $l.");

      $l = uri_escape($l);
      print $q->redirect("rep.cgi?user=$l");
    } else {
      my $err = $DBI::errstr;
      &R2db::dblog("ошибка при переключении состояния уведомления по e-mail, пользователь $l, $err.");
      &R2utils::print_start_hdr;
      print "<p>Ошибка при переключении состояния уведомления по e-mail!</p><p>Пожалуйста сообщите об ошибке в группу сетевого администрирования.</p>";
      &R2utils::print_end_hdr;
    }
  }
}

