#!/usr/bin/perl

require 'r2ad.pm';

use warnings;
use strict;

my $entry = &R2ad::lookup_ad('aV');
unless ($entry) { print "lookup_ad() returns undef\n"; exit; } 

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

print "cn: ", $ad_cn, "\n";
print "sn: ", $ad_sn, ", givenname: ", $ad_givenname, "\n";
print "title: ", $ad_title, "\n"; 
print "mail: ", $ad_mail, "\n"; 
print "room: ", $ad_room, "\n"; 
print "tel: ", $ad_tel, "\n"; 
print "company: ", $ad_company, "\n";

