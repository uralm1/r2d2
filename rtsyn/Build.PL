use strict;
use warnings;

use Module::Build;
use Module::CPANfile;

my $inst_dir = '/opt/rtsyn'; #FIXME

my $class = Module::Build->subclass(
code => <<'SUBCLASS');
  sub process_conf_files { print "in process_conf_files()\n";}

  sub ACTION_build {
    my $self = shift;
    print " ** Checking...\n";

    $self->SUPER::ACTION_build;
  }

  sub ACTION_install {
    my $self = shift;
    $self->SUPER::ACTION_install;

    print " ** Installing configuration, public and templates files...\n";
  }
SUBCLASS

my $cpanfile = Module::CPANfile->load('cpanfile');
my $prereq = $cpanfile->prereq_specs;

my $build = $class->new(
  module_name => 'Rtsyn',
  dist_name => 'rtsyn',
  dist_author => 'Ural Khasanov <uralm1@uwc.ufanet.ru>',
  dist_abstract => 'Rtsyn r2d2 agent',
  dist_version_from => 'lib/Rtsyn.pm',

  requires => $prereq->{runtime}{requires},
  configure_requires => $prereq->{configure}{requires},
  test_requires => $prereq->{test}{requires},

  install_path => {
    prefix => $inst_dir,
    lib => "$inst_dir/lib",
    script => "$inst_dir/script",
    conf => $inst_dir,
  },

  conf_files => {'rtsyn.conf_empty' => 'rtsyn.conf'},
  script_files => {'script/rtsyn' => 'script/rtsyn'},

);

$build->add_build_element('conf');
$build->add_build_element('script');
$build->add_build_element('run');

$build->create_build_script;
