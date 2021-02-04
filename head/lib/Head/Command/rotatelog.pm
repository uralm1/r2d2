package Head::Command::rotatelog;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;
use Mojo::IOLoop;

has description => '* Rotate or clean database log (run from cron cmd)';
has usage => "Usage: APPLICATION rotatelog [--clean]\n";

sub run {
  my ($self, $op) = @_;
  my $app = $self->app;
  $op //= '';

  if ($op eq '-c' || $op eq '--clean') {
    my $e = eval {
      $app->mysql_inet->db->query("DELETE FROM op_log");
    };
    if (defined $e) {
      $app->log->info('Database log successfully cleaned.');
      $app->dblog->l(info => 'Database log cleaned.');
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
      $app->log->info('Database log successfully rotated.');
      $app->dblog->l(info => 'Database log rotated.');
    } else {
      $app->log->error('Rotate log SQL operation failed.');
      return undef;
    }
  }

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 1;
}

1;
