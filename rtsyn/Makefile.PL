use strict;
use warnings;

use ExtUtils::MakeMaker;

my $inst_dir = '/etc/r2d2';

WriteMakefile(
  NAME => 'Rtsyn',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'rtsyn',
  VERSION_FROM   => 'lib/Rtsyn.pm',
  PREREQ_PM => {
    'Mojolicious' => '8.50',
    'EV' => 0,
    'Cpanel::JSON::XS' => '4.10',
    'IO::Socket::SSL' => '2.009',
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
  #  'lib/Rtsyn.pm' => '$(INST_LIB)/Rtsyn.pm',
  #},
  INSTALLSCRIPT => "$inst_dir/script",
  INSTALLSITESCRIPT => "$inst_dir/script",
  EXE_FILES => ['script/rtsyn'],
  MAN1PODS => {},
  MAN3PODS => {},
);

package MY;
sub install {
  my $inherited = shift->SUPER::install(@_);
  return $inherited.<<"MAKE_FRAG";
install::
	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
	\$(NOECHO) install -m 0644 rtsyn.conf_empty \$(DESTDIR)$inst_dir/rtsyn.conf_empty
	\$(NOECHO) [ ! -f \$(DESTDIR)$inst_dir/rtsyn.conf ] && install -b -m 0644 rtsyn.conf_empty \$(DESTDIR)$inst_dir/rtsyn.conf || true

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."

MAKE_FRAG
}

