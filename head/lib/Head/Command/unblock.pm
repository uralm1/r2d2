package Head::Command::unblock;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;

has description => '* Run unblock check process (run from cron cmd)';
has usage => "Usage: APPLICATION unblock\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $db = $app->mysql_inet->db;

  $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;

  $app->log->info('Unblock devices - checking db');

  my $selected = 0; # counter

  my $unblock_results = eval { $db->query("SELECT id, profile FROM devices \
WHERE blocked = 1 AND (sum_limit_in > 0 OR qs = 0 OR qs = 1)") };
  unless (defined $unblock_results) {
    $app->log->error("Unblock: database operation error: $@");
  } else {
    while (my $n = $unblock_results->hash) {
      $app->log->debug("Device to unblock: $n->{id}, $n->{profile}");
      # unblock
      $app->minion->enqueue(block_client => [$n->{id}, 0, $n->{profile}]);
      $selected++;

    } # loop by devices
  }

  return $selected;
}

1;
