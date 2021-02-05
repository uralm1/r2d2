package Head::Command::truncatelog;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;
use Mojo::IOLoop;

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
      $app->dblog->info('Database oplog cleaned.');
    } else {
      $app->log->error('Clean log SQL operation failed.');
      return undef;
    }

  } else {
    # keep last 1000 records
    my $e = eval {
      $app->mysql_inet->db->query("DELETE FROM op_log WHERE id <= ( \
SELECT id FROM (SELECT id FROM op_log ORDER BY id DESC LIMIT 1 OFFSET 1000) foo )");
    };
    if (defined $e) {
      $app->log->info('Database oplog successfully truncated.');
      $app->dblog->info('Database oplog truncated.');
    } else {
      $app->log->error('Truncate log SQL operation failed.');
      return undef;
    }
  }

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 1;
}

1;
