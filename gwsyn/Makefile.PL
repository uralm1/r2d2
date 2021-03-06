use strict;
use warnings;

use ExtUtils::MakeMaker;

my $inst_dir = '/etc/r2d2';

WriteMakefile(
  NAME => 'Gwsyn',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'gwsyn',
  VERSION_FROM   => 'lib/Gwsyn.pm',
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
  #  'lib/Gwsyn.pm' => '$(INST_LIB)/Gwsyn.pm',
  #},
  INSTALLSCRIPT => "$inst_dir/script",
  INSTALLSITESCRIPT => "$inst_dir/script",
  EXE_FILES => ['script/gwsyn'],
  MAN1PODS => {},
  MAN3PODS => {},
);

package MY;
sub install {
  my $inherited = shift->SUPER::install(@_);
  return $inherited.<<"MAKE_FRAG";
install::
	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
	\$(NOECHO) install -m 0644 gwsyn.conf_empty \$(DESTDIR)$inst_dir/gwsyn.conf_empty
	\$(NOECHO) [ ! -f \$(DESTDIR)$inst_dir/gwsyn.conf ] && install -b -m 0644 gwsyn.conf_empty \$(DESTDIR)$inst_dir/gwsyn.conf || true

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."

MAKE_FRAG
}

