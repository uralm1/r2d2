package Master::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Master::Ural::Dblog;
use Master::Ural::Rtref qw(rtsyn_refresh);

has description => '* Run check for database changes manually';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Asyncronious update initiated for rtsyn');
  rtsyn_refresh($app);

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}


1;
