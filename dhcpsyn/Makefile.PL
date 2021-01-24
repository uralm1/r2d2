use strict;
use warnings;

use ExtUtils::MakeMaker;

# WARNING: this is for WINDOWS
my $inst_dir = '/utils/dhcpsyn';

WriteMakefile(
  NAME => 'Dhcpsyn',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'dhcpsyn',
  VERSION_FROM   => 'lib/Dhcpsyn.pm',
  PREREQ_PM => {
    'Mojolicious' => '8.50',
    'EV' => 0,
    'Cpanel::JSON::XS' => '4.10',
    'IO::Socket::SSL' => '2.009',
    'Minion' => '10.03',
    'Minion::Backend::SQLite' => 0,
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
  #  'lib/Dhcpsyn.pm' => '$(INST_LIB)/Dhcpsyn.pm',
  #},
  INSTALLSCRIPT => "$inst_dir/script",
  INSTALLSITESCRIPT => "$inst_dir/script",
  EXE_FILES => ['script/dhcpsyn'],
  MAN1PODS => {},
  MAN3PODS => {},
);

# next shell commands doesn't work in WINDOWS
#package MY;
#sub install {
#  my $inherited = shift->SUPER::install(@_);
#  return $inherited.<<"MAKE_FRAG";
#install::
#	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
#	\$(NOECHO) install -m 0644 dhcpsyn.conf_empty \$(DESTDIR)$inst_dir/dhcpsyn.conf
#
#MAKE_FRAG
#}
#
#sub postamble {
#  return <<'MAKE_FRAG';
#all::
#	$(NOECHO) $(ECHO) "** Checking..."
#	$(NOECHO) if grep -q -e "^\s*\$$self->plugin(['|\"]Minion::Admin['|\"]);" lib/Dhcpsyn.pm ; then echo "\nWARNING! DEBUG MINION ADMIN PAGE in Dhcpsyn.pm IS NOT DISABLED!!!\n"; fi
#
#MAKE_FRAG
#}

