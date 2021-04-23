package Head::Task::ProcDaily;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(proc_daily => sub {
    my $job = shift;
    my $app = $job->app;

    my $m = 'DAILY processing started';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    # archive traffic statistics
    my $r = eval { $app->mysql_inet->db->query("INSERT INTO adaily (client_id, login, date, d_in, d_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE d_in = sum_in, d_out = sum_out") };
    unless ($r) {
      $m = 'DAILY archive SQL operation failed. Task stopped.';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);

      $job->fail;
      return;
    }

    $m = 'DAILY processing finished';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $job->finish;
  });
}


1;
