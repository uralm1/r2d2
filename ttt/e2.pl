#!/usr/bin/perl

use warnings;
use strict;

my $s1='asd';
my $s2='';
my $s3;
my $s4='zzz';
my @l;
push @l, $s1;
push @l, $s2;
#push @l, $s3;
push @l, $s4;

print "***".join(' ',@l)."***\n";
