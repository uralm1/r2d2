#!/usr/bin/perl
#
use strict;
use warnings;
use v5.12;
use Data::Dumper;
use FindBin;

my $cfg;
{ # slurp config
  open my $fh, '<', "$FindBin::Bin/../r2d2.conf" or die "Can't read config file!\n";
  local $/ = undef;
  $cfg = eval <$fh>;
  close $fh;
}
die "Error found in config file.\n" if (!$cfg or ref($cfg) ne 'HASH');

say Dumper $cfg;
