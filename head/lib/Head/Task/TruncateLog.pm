package Head::Task::TruncateLog;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(truncate_log => sub {
    my $job = shift;
    my $app = $job->app;

    my $m = 'Truncate log operation started';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    # keep last 1000 records
    my $e = eval {
      $app->mysql_inet->db->query("DELETE FROM op_log WHERE id <= ( \
SELECT id FROM (SELECT id FROM op_log ORDER BY id DESC LIMIT 1 OFFSET 1000) foo )");
    };
    if (defined $e) {
      $m = 'Database oplog successfully truncated';
      $app->log->info($m);
      $app->dblog->info($m, sync=>1);
    } else {
      $m = 'Truncate log SQL operation failed';
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
    }

    $m = 'Truncate log operation finished';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $job->finish;
  });
}


1;
