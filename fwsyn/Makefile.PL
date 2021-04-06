use strict;
use warnings;

use ExtUtils::MakeMaker;

my $inst_dir = '/etc/r2d2';

WriteMakefile(
  NAME => 'Fwsyn',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'fwsyn',
  VERSION_FROM   => 'lib/Fwsyn.pm',
  PREREQ_PM => {
    'Mojolicious' => '8.50',
    'EV' => 0,
    'Cpanel::JSON::XS' => '4.10',
    'IO::Socket::SSL' => '2.009',
    'Algorithm::Cron' => '0.10',
    'Ljq' => 0,
  },
  TEST_REQUIRES => {
    'Test::More' => 0,
    'Test::Files' => 0,
    'Test::Mojo' => 0,
  },
  test => {TESTS => 't/*.t'},
  PREFIX => $inst_dir,
  LIB => "$inst_dir/lib",
  #PMLIBDIRS => ['lib'],
  #PM => {
  #  'lib/Fwsyn.pm' => '$(INST_LIB)/Fwsyn.pm',
  #},
  INSTALLSCRIPT => "$inst_dir/script",
  INSTALLSITESCRIPT => "$inst_dir/script",
  EXE_FILES => ['script/fwsyn'],
  MAN1PODS => {},
  MAN3PODS => {},
);

package MY;
sub install {
  my $inherited = shift->SUPER::install(@_);
  return $inherited.<<"MAKE_FRAG";
install::
	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
	\$(NOECHO) install -m 0644 fwsyn.conf_empty \$(DESTDIR)$inst_dir/fwsyn.conf_empty
	\$(NOECHO) [ ! -f \$(DESTDIR)$inst_dir/fwsyn.conf ] && install -b -m 0644 fwsyn.conf_empty \$(DESTDIR)$inst_dir/fwsyn.conf || true

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."

MAKE_FRAG
}

