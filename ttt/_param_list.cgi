#!/usr/bin/perl -wT

use strict;
use CGI;

my $q = new CGI;
print $q->header("text/plain");

print ("Были получены следующие значения:\n\n");

my ($name, $value);

foreach $name ($q->param) {
  print "$name: \n";
  foreach $value ($q->param($name)) {
    print " $value\n";
  }
}
