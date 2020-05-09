#!/usr/bin/perl

use warnings;
use NetAddr::MAC;

eval {$m = NetAddr::MAC->new('00:1:22:aa:bb:cc');};
if ($@) {print"Error: $@\n";}

if (!$m) {die;}
print $m->as_basic, "\n" ;
print $m->as_microsoft, "\n" ;
#print $m, "\n"; #this doesn't work

