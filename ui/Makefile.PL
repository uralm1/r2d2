use strict;
use warnings;

#use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::CPANfile;

my $inst_dir = '/opt/ui';

WriteMakefile(
  NAME => 'Ui',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'ui',
  VERSION_FROM   => 'lib/Ui.pm',
  #PREREQ_PM => {
  #  'Mojolicious' => '8.50',
  #  'EV' => 0,
  #  'Cpanel::JSON::XS' => '4.10',
  #  'IO::Socket::SSL' => '2.009',
  #  'Net::LDAP' => 0,
  #},
  test => {TESTS => 't/*.t'},
  PREFIX => $inst_dir,
  LIB => "$inst_dir/lib",
  #PMLIBDIRS => ['lib'],
  #PM => {
  #  'lib/Ui.pm' => '$(INST_LIB)/Ui.pm',
  #},
  INSTALLSCRIPT => "$inst_dir/script",
  INSTALLSITESCRIPT => "$inst_dir/script",
  EXE_FILES => ['script/ui'],
  MAN1PODS => {},
  MAN3PODS => {},
);

package MY;
sub install {
  my $inherited = shift->SUPER::install(@_);
  return $inherited.<<"MAKE_FRAG";
install::
	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
	\$(NOECHO) install -m 0644 ui.conf_empty \$(DESTDIR)$inst_dir/ui.conf_empty
	\$(NOECHO) [ ! -f \$(DESTDIR)$inst_dir/ui.conf ] && install -m 0644 ui.conf_empty \$(DESTDIR)$inst_dir/ui.conf || true
	\$(NOECHO) for d in \$\$(find public -type d); do install -m 0755 -d \$(DESTDIR)$inst_dir/\"\$\$d\"; done
	\$(NOECHO) for f in \$\$(find public -type f); do install -m 0644 -D \"\$\$f\" \$(DESTDIR)$inst_dir/\"\$\$f\"; done
	\$(NOECHO) for d in \$\$(find templates -type d); do install -m 0755 -d \$(DESTDIR)$inst_dir/\"\$\$d\"; done
	\$(NOECHO) for f in \$\$(find templates -type f); do install -m 0644 -D \"\$\$f\" \$(DESTDIR)$inst_dir/\"\$\$f\"; done
	\$(NOECHO) if [ \"\$\$(id -u)\" != \"0\" ]; then install -m 0755 -d \$(DESTDIR)$inst_dir/run; else install -o ui -g ui -m 0755 -d \$(DESTDIR)$inst_dir/run; fi

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."
	$(NOECHO) if grep -q -e "^\s*\$$remote_user = ['|\"]" lib/Ui.pm ; then echo "\nWARNING! DEBUG ENTRY AUTHORIZATION CODE in Ui.pm IS NOT DISABLED!!!\n"; fi

MAKE_FRAG
}

