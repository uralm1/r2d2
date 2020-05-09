#!/usr/bin/perl

use warnings;
use strict;

use Net::SMTP;

my $fullname = "Иванов Иван Иванович";
my $from = 'r2d2@testdomain';
my $smtp_host = 'mail.testdomain';
my $to = 'fidan@testdomain';


my @ll;
open(TPLFILE, '<', 'mail_warn.txt') or die "Can't open template file: $!\n";
while (<TPLFILE>) {
  my $s = '';
  while (/%%([A-Za-z0-9_-]+)%%/) {
    $s = $`;
    if ($1 eq 'USERNAME') {
      $s .= $fullname;
    } elsif ($1 eq 'USEREMAIL') {
      $s .= $to;
    } else {
      $s .= $&;
      warn "Unhandled template $& found.\n";
    }
    $_ = $';
  }
  push @ll, $s . $_;
}
close TPLFILE;

my $smtp = Net::SMTP->new($smtp_host, Hello => 'fw.testdomain', Timeout => 10, Debug => 1);
unless ($smtp) {
  die "Create object failed.\n";
}

$smtp->mail($from);
$smtp->to($to);

$smtp->data(@ll);

$smtp->quit;


