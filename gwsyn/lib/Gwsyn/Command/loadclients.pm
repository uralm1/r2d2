package Gwsyn::Command::loadclients;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Reload all client data from the Head like on restart';
has usage => "Usage: APPLICATION loadclients\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Reloading all clients configuration');
  unless (eval { $app->load_clients }) {
    $app->log->error("Loading clients failed: $@");
    return 1;
  }

  return 0;
}

1;
