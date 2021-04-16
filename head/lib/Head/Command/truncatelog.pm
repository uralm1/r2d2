package Head::Command::truncatelog;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;

has description => '* Truncate or clean database oplog (run from cron cmd)';
has usage => "Usage: APPLICATION truncatelog [--clean]\n";

sub run {
  my ($self, $op) = @_;
  my $app = $self->app;
  $op //= '';

  if ($op eq '-c' || $op eq '--clean') {
    my $e = eval {
      $app->mysql_inet->db->query("DELETE FROM op_log");
    };
    if (defined $e) {
      $app->log->info('Database oplog successfully cleaned.');
      $app->dblog->info('Database oplog cleaned.', sync=>1);
    } else {
      $app->log->error('Clean log SQL operation failed.');
      return undef;
    }

  } else {
    $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;

    # keep last 1000 records
    my $id = $app->minion->enqueue('truncate_log');
    $app->log->info("Truncate log task $id was enqueued");
  }

  return 1;
}

1;
