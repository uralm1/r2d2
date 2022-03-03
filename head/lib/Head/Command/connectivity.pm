package Head::Command::connectivity;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::Util qw(getopt);

has description => '* Check agents connectivity (run from cron cmd)';
has usage => "Usage: APPLICATION connectivity [<profile>]\n";

sub run {
  my $app = shift->app;

  getopt \@_, 'cron'=>\my $cron
    or die "Error in commandline arguments\n";

  die "Not supported\n" if $cron;

  $app->log->info('Connectivity check started.');
  unless (defined eval { Head::Task::Connectivity::_do($app, @_) }) {
    chomp $@;
    die "Fatal error. $@\n";
  }
  $app->log->info('Connectivity check performed.');

  return 1;
}


1;
