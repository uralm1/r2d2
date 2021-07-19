package Gwsyn::Command::loaddevices;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Reload all devices data from the Head like on restart';
has usage => "Usage: APPLICATION loaddevices\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Reloading all devices configuration');
  if ($app->check_workers) {
    $app->ljq->enqueue('load_devices');
  } else {
    $app->log->error("Command canceled. Execution subsystem error.");
    return 1;
  }

  return 0;
}

1;
