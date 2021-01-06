package Gwsyn::Command::trafstat;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Do traffic statistics collection (run from cron cmd)';
has usage => "Usage: APPLICATION trafstat\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Initiate traffic statistics collection');
  if ($app->check_workers) {
    $app->minion->enqueue('traffic_stat');
  } else {
    $app->log->error("Command cancelled. Execution subsystem error.");
    return 1;
  }

  return 0;
}

1;
