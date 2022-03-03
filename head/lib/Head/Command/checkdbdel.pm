package Head::Command::checkdbdel;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::Util qw(getopt);

has description => '* Run check for database deletions (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdbdel\n";

sub run {
  my $app = shift->app;

  binmode(STDOUT, ':utf8');

  getopt \@_, 'cron'=>\my $cron
    or die "Error in commandline arguments";

  die "Not supported\n" if $cron;

  $app->log->info('Check device database for deleted devices.');
  unless (defined eval { Head::Task::CheckDBDel::_do($app) }) {
    chomp $@;
    die "Fatal error. $@\n";
  }
  $app->log->info('Check for deleted devices completed.');

  return 1;
}


1;
