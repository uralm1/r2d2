#!/usr/bin/perl

use warnings;
use Date::Simple ('today');

$d1 = today();
$d2 = Date::Simple->new('1976-01-19');

$d1--;

my $daycount = today();
my $days_month = Date::Simple::days_in_month(today()->year, today()->month);
my $dayend = today() - $days_month;

print $d1, ' ', $d2, "\n";
print $daycount, ' ', $days_month, ' ', $dayend, "\n";

