use strict;
use warnings;

#use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::CPANfile;

my $inst_dir = '/opt/master';

WriteMakefile(
  NAME => 'Master',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'master',
  VERSION_FROM   => 'lib/Master.pm',
  #PREREQ_PM => {
  #  'Mojolicious' => '8.09',
  #  'Mojo::mysql' => '1.04',
  #},
  test      => {TESTS => 't/*.t'},
  PREFIX => $inst_dir,
  LIB => "$inst_dir/lib",
  #PMLIBDIRS => ['lib'],
  #PM => {
  #  'lib/Master.pm' => '$(INST_LIB)/Master.pm',
  #  'script/master' => '$(INST_SCRIPT)/master',
  #},
  MAN1PODS => {},
  MAN3PODS => {},
);

package MY;
sub install {
  my $inherited = shift->SUPER::install(@_);
  return $inherited.<<"MAKE_FRAG";
install::
	\$(NOECHO) \$(ECHO) "** Installing configuration, public and templates files..."
	\$(NOECHO) install -m 0644 master.conf_empty \$(DESTDIR)$inst_dir/master.conf
	\$(NOECHO) install -m 0755 -d \$(DESTDIR)$inst_dir/script
	\$(NOECHO) install -D script/* \$(DESTDIR)$inst_dir/script
	\$(NOECHO) if [ \"\$\$(id -u)\" != \"0\" ]; then install -m 0755 -d \$(DESTDIR)$inst_dir/run; else install -o master -g master -m 0755 -d \$(DESTDIR)$inst_dir/run; fi

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."

MAKE_FRAG
}

