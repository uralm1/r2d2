#!/usr/bin/perl

use warnings;
use Net::LDAP;


my $ldap = Net::LDAP->new(['ldap://srv1', 'ldap://srv2'],
  port => 389, timeout => 3) or die "$@\n";

#my $base = "OU=UWC Users,DC=uwc,DC=local";
my $base = "DC=uwc,DC=local";

# Set LDAP credentials here
my $mesg = $ldap->bind('user', password => 'pass', version => 3);
if ($mesg->code) {
  print "Ldap bind error: ".$mesg->error."\n";
  die;
}

my $l = 'av';
print "Searching AD for object: $l\n";
my $filter = "(&(objectClass=person)(sAMAccountName=$l))";
my $res = $ldap->search(base=>$base, filter=>$filter,
  attrs=>'cn,sn,givenname,title,mail,physicaldeliveryofficename,telephonenumber,company');
if ($res->code) {
  print "Ldap search error: ".$res->error."\n";
  die;
}

my $count = $res->count;
if ($count > 0) {
  my $entry = $res->entry(0);
  my $ad_cn = $entry->get_value('cn');
  my $ad_sn = $entry->get_value('sn');
  my $ad_givenname = $entry->get_value('givenname');
  my $ad_title = $entry->get_value('title');
  my $ad_mail = $entry->get_value('mail');
  my $ad_room = $entry->get_value('physicaldeliveryofficename');
  my $ad_tel = $entry->get_value('telephonenumber');
  my $ad_company = $entry->get_value('company');
  $ad_cn = "" unless $ad_cn;
  $ad_sn = "" unless $ad_sn;
  $ad_givenname = "" unless $ad_givenname;
  $ad_title = "" unless $ad_title;
  $ad_mail = "" unless $ad_mail;
  $ad_room = "" unless $ad_room;
  $ad_tel = "" unless $ad_tel;
  $ad_company = "" unless $ad_company;

  print "Found: $count\n";
  print "cn: ", $ad_cn, "\n";
  print "sn: ", $ad_sn, ", givenname: ", $ad_givenname, "\n";
  print "title: ", $ad_title, "\n"; 
  print "mail: ", $ad_mail, "\n"; 
  print "room: ", $ad_room, "\n"; 
  print "tel: ", $ad_tel, "\n"; 
  print "company: ", $ad_company, "\n";
} else {
  print "Found nothing.\n"
}

$ldap->unbind;
exit;

