package Head::Task::TruncateLog;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(truncate_log => sub {
    my $job = shift;
    my $app = $job->app;

    $app->log->info('Truncate log operation started');

    unless (defined eval { _do($app) }) {
      chomp $@;
      $app->log->error("Fatal error. $@");
      $app->dblog->error('Truncate log SQL operation failed', sync=>1);
    } else {
      ###
      $app->dblog->info('Truncate log operation performed', sync=>1);
    }

    $app->log->info('Truncate log operation finished');
    $job->finish;
  });
}


# _do($app)
# dies on error (database)
sub _do {
  # keep last 5000 records
  shift->mysql_inet->db->query("DELETE FROM op_log WHERE id <= ( \
SELECT id FROM (SELECT id FROM op_log ORDER BY id DESC LIMIT 1 OFFSET 5000) foo )");
}


1;
