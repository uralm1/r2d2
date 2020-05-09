#!/usr/bin/perl

use warnings;
use NetAddr::IP;

$ip = NetAddr::IP->new('01.00012.034.9');

if (!$ip) {die;}
print "The address is ", $ip->addr, " mask ", $ip->mask, "\n" ;
print "You can also say $ip...\n";
print $ip->numeric, "\n";
print $ip->aton, "\n";

$aaa = $ip->numeric;
print $aaa, "\n";
$ip2 = NetAddr::IP->new($aaa);
if (!$ip2) {die;}
print "ip2 ", $ip2->addr, " mask ", $ip2->mask, "\n" ;

