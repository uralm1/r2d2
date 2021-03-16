package Fwsyn::Command::loadclients;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Reload all client data from the Head like on restart';
has usage => "Usage: APPLICATION loadclients\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Reloading all clients configuration');
  if ($app->check_workers) {
    $app->minion->enqueue('load_clients');
  } else {
    $app->log->error("Command canceled. Execution subsystem error.");
    return 1;
  }

  return 0;
}

1;