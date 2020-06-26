#!/usr/bin/perl

use warnings;
use NetAddr::IP::Lite;

$ip = NetAddr::IP::Lite->new('01.00012.034.9');

die unless $ip;
print "The address is ", $ip->addr, " mask ", $ip->mask, "\n" ;
print "You can also say $ip...\n";
print $ip->numeric, "\n";
print $ip->aton, "\n";

$aaa = $ip->numeric;
print $aaa, "\n";
$ip2 = NetAddr::IP::Lite->new($aaa);
die unless $ip;
print "ip2 ", $ip2->addr, " mask ", $ip2->mask, "\n" ;

