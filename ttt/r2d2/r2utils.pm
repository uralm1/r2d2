#!/usr/bin/perl
# This is the part of R2D2
# Common code
# author: Ural Khassanov, 2013
#

package R2utils;

use strict;
use warnings;
use CGI;

# common version for all cgi-s
my $cgi_version = 'v1.39';

# administrators
my @admin_list = qw( ural av );

my $cgi_modname; # adm/admrep/rep etc...
my $cgi_title; # html title
my $cgi_footername; # ...footer
my $cgi_print_footer_support;

$CGI::DISABLE_UPLOADS = 1;
#$CGI::POST_MAX = 100;
my $cgi = new CGI;;

# check authentication
if (!$cgi->remote_user) {
  # uncomment this!
  die "Called with empty REMOTE_USER?! This is security problem!\n";
}

# remove this ugly @UWC.LOCAL realm from username
#$cgi->remote_user =~ /^(.*)\@UWC\.LOCAL$/;
#my $cgi_remote_user = $1;
my $cgi_remote_user = $cgi->remote_user;

my $is_admin_flag = (grep {/^$cgi_remote_user$/i} @admin_list);

#--------------------------------------------------
sub cgi {
  return $cgi;
}

sub version {
  return $cgi_version;
}

sub fullversion {
  return 'r2d2.'.$cgi_modname.' '.$cgi_version;
}

sub remote_user {
  return $cgi_remote_user;
}

sub is_admin {
  return $is_admin_flag;
}

# &R2utils::set_modname('admrep')
sub set_modname {
  $cgi_modname = shift;
}

# &R2utils::set_footername('Отчеты по трафику', 1)
sub set_footername {
  $cgi_footername = shift;
  $cgi_print_footer_support = shift;
}

# &R2utils::set_title('Отчет по трафику для пользователя')
sub set_title {
  $cgi_title = shift;
}

sub print_start_hdr {
  print $cgi->header(-type => "text/html", -charset => "utf-8");
  print <<HTML_START_HDR;
<!DOCTYPE HTML><html><head><title>$cgi_title</title>
<meta http-equiv="content-type" content="text/html;charset=utf-8">
<link rel="icon" type="image/vnd.microsoft.icon" href="img/favicon.ico"/>
<link rel="shortcut icon" type="image/vnd.microsoft.icon" href="img/favicon.ico"/>
<style type="text/css"><!--body{font-family:sans-serif;font-size:11pt}table.db,table.db th,table.db td{border:1px solid #a9a9a9;border-collapse:collapse;padding:2px;}table.db th{background-color:#fffebe;}img.db{border:none;margin-left:2px;margin-right:1px}--></style>
</head><body>
HTML_START_HDR
  print $cgi->h1("Корпоративный интернет");
}

sub print_end_hdr {
  print "<br><br><hr>";
  print "<a href=\"https://faq.uwc.ufanet.ru\" target=\"_blank\">Часто-задаваемые вопросы (FAQ) по сети Интернет</a>.<br>" if $cgi_print_footer_support;
  print "<span title=\"автор: Урал Хасанов, 2013\">$cgi_footername</span> (",&fullversion,')';
  print ". Проблемы? Оставьте заявку в <a href=\"https://otk.uwc.ufanet.ru/otrs\" target=\"_blank\">системе поддержки пользователей</a>." if $cgi_print_footer_support;
  print "</body></html>";
}

sub print_bad_query {
  &print_start_hdr;
  print "<p>Неверный запрос.</p>";
  &print_end_hdr;
}

# $mb = &R2utils::btomb(1024)
sub btomb {
  return sprintf('%.1f', shift() / 1048576);
}

# $b = &R2utils::mbtob(1024)
sub mbtob {
  return shift() * 1048576;
}

###
1;

