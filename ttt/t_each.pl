#!/usr/bin/perl

use Mojo::Base -strict;

my $h = {
  key1 => 'value1',
  key2 => 'value2',
  key3 => 'value3',
  key4 => 'value4',
  key5 => 'value5',
};

#while (my ($k, $v) = each %$h) {
#  say "$k, $v";
#}

sub sub1 {
  my $hash = shift;
  my ($k, $v);
  return unless( ($k, $v) = each %$hash );
  say "sub1: $k, $v";
  sub1($hash);
}


sub1($h);
