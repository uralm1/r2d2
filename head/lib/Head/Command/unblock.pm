package Head::Command::unblock;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;

has description => '* Run unblock check process (run from cron cmd)';
has usage => "Usage: APPLICATION unblock\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $dbconn = $app->mysql_inet->db;

  $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;

  $app->log->info('Unblock clients - checking db');
  my $unblock_results = eval { $dbconn->query("SELECT id, profile FROM clients \
WHERE blocked = 1 AND (sum_limit_in > 0 OR qs = 0 OR qs = 1)") };
  unless ($unblock_results) {
    $app->log->error("Unblock: database operation error: $@");
  } else {
    while (my $n = $unblock_results->hash) {
      $app->log->debug("Client to unblock: $n->{id}, $n->{profile}");
      # unblock
      $app->minion->enqueue(block_client => [$n->{id}, 0, $n->{profile}]);
    } # loop by clients
  }

  return 1;
}

1;
