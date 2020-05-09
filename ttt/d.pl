#!/usr/bin/perl

use warnings;

my $rr='@UWC.LOCAL';
print $rr=~/^(.*)\@.*$/;

my @a=qw(asFf Cvbc tyhrty);
my $b="asff";
if (grep {/^$b$/i} @a) { print "found"; }

