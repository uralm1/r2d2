package Head::Command::cleanlog;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::mysql;

has description => '* Clean database log';
has usage => "Usage: APPLICATION cleanlog\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $e = eval {
    $app->mysql_inet->db->query("DELETE FROM op_log");
  };
  if (defined $e) {
    $app->log->info('Database log successfully cleaned.');
  } else {
    $app->log->error('Clean log SQL operation failed.');
  }

  return 0;
}

1;
