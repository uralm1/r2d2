package Head::Command::checkclients;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::Util qw(getopt);

has description => '* Run check for clients changes (run from cron cmd)';
has usage => "Usage: APPLICATION checkclients\n";

sub run {
  my $app = shift->app;

  binmode(STDOUT, ':utf8');

  getopt \@_, 'cron'=>\my $cron
    or die "Error in commandline arguments.\n";

  die "Not supported\n" if $cron;

  unless (defined eval { Head::Task::CheckClients::_do($app) }) {
    chomp $@;
    die "Fatal error. $@\n";
  } else {
    $app->log->info('Manual rescan clients for changes completed.');
  }

  return 1;
}


1;
