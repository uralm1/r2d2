use strict;
use warnings;

#use ExtUtils::MakeMaker;
use ExtUtils::MakeMaker::CPANfile;

my $inst_dir = '/opt/head';

WriteMakefile(
  NAME => 'Head',
  AUTHOR => 'Ural Khasanov <uralm@uwc.ufanet.ru>',
  DISTNAME => 'head',
  VERSION_FROM   => 'lib/Head.pm',
  #PREREQ_PM => {
  #  'Mojolicious' => '8.09',
  #  'Mojo::mysql' => '1.04',
  #},
  test      => {TESTS => 't/*.t'},
  PREFIX => $inst_dir,
  LIB => "$inst_dir/lib",
  #PMLIBDIRS => ['lib'],
  #PM => {
  #  'lib/Head.pm' => '$(INST_LIB)/Head.pm',
  #  'script/head' => '$(INST_SCRIPT)/head',
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
	\$(NOECHO) install -m 0644 head.conf_empty \$(DESTDIR)$inst_dir/head.conf
	\$(NOECHO) install -m 0755 -d \$(DESTDIR)$inst_dir/script
	\$(NOECHO) install -D script/* \$(DESTDIR)$inst_dir/script
	\$(NOECHO) if [ \"\$\$(id -u)\" != \"0\" ]; then install -m 0755 -d \$(DESTDIR)$inst_dir/run; else install -o head -g head -m 0755 -d \$(DESTDIR)$inst_dir/run; fi

MAKE_FRAG
}

sub postamble {
  return <<'MAKE_FRAG';
all::
	$(NOECHO) $(ECHO) "** Checking..."

MAKE_FRAG
}

