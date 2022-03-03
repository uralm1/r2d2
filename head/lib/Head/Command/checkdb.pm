package Head::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::Util qw(getopt);

has description => '* Run check for database changes (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $app = shift->app;

  binmode(STDOUT, ':utf8');

  getopt \@_, 'cron'=>\my $cron
    or die "Error in commandline arguments";

  die "Not supported\n" if $cron;

  $app->log->info('Check sync queue flags.');
  unless (defined eval { Head::Task::CheckDB::_do($app) }) {
    chomp $@;
    die "Fatal error. $@\n";
  }
  $app->log->info('Check sync queue flags performed.');

  return 1;
}


1;
