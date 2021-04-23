#!/usr/bin/perl

package Test::UserException {
  use Mojo::Base 'Mojo::Exception';
}

package main;

use Mojo::Base -strict;
use Mojo::Exception qw(check raise);
use Data::Dumper;

say "start";

test(1);

say "now 2";
my $e = eval { test(2) };
unless (defined $e) {
  if (ref($@) eq 'Mojo::Exception') {
    say "Mojo::Exception error: $@";
  } else {
    chomp $@;
    say "error: $@";
  }
  exit;
}
#say Dumper $@;

# WARNING: this syntax doesn't work for Mojo < 8.73!
#check $@ => [
#  'Mojo::Exception' => sub { say "Mojo::Exception error: $_"; },
#  default => sub { say "error: $_"; },
#];
#say "check returned: $bool";

say "function returned: $e";
say "finish";

sub test {
  my $p = shift;
  if ($p == 2) {
    # die always has new line!
    die "exception 2 [die]\n";
  } elsif ($p == 3) {
    Mojo::Exception->throw('exception 3 [Mojo::Exception]');
  } elsif ($p == 4) {
    Test::UserException->throw('exception 4 [Test::UserException]');
  } elsif ($p == 5) {
    raise 'Test::UserException::EE', 'exception 5 [Test::UserException::EE]';
  } elsif ($p == 6) {
    #
  }

  return "This is returned value";
}

