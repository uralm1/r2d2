package Head::Command::truncatelog;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;
use Mojo::Util qw(getopt);

has description => '* Truncate or clean database logs (run from cron cmd)';
has usage => "Usage: APPLICATION truncatelog [--clean]\n";

sub run {
  my $app = shift->app;

  getopt \@_, 'clean|c'=>\my $clean, 'cron'=>\my $cron
    or die "Error in commandline arguments.\n";

  if ($clean) {
    my $e = eval { $app->mysql_inet->db->query("DELETE FROM op_log") };
    if (defined $e) {
      $app->dblog->info('Database oplog cleaned.', sync=>1);
    } else {
      $app->log->error('Clean oplog SQL operation failed.');
      return undef;
    }

    $e = eval { $app->mysql_inet->db->query("DELETE FROM audit_log") };
    if (defined $e) {
      $app->log->info('Log databases successfully cleaned.');
      $app->dblog->audit('Выполнено ручное удаление логов.', sync=>1);
    } else {
      $app->log->error('Clean audit log SQL operation failed.');
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
