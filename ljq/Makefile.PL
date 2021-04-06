use strict;
use warnings;

use ExtUtils::MakeMaker;

my $inst_dir = '/etc/r2d2';

WriteMakefile(
  NAME => 'Ljq',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'ljq',
  VERSION_FROM   => 'lib/Ljq.pm',
  PREREQ_PM => {
    'Mojolicious' => '8.50',
  },
  TEST_REQUIRES => {
    'Test::More' => 0,
    'Test::Mojo' => 0,
  },
  test => {TESTS => 't/*.t'},
  PREFIX => $inst_dir,
  LIB => "$inst_dir/lib",
  MAN1PODS => {},
  MAN3PODS => {},
);
