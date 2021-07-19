package Head::Task::ProcYearly;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(proc_yearly => sub {
    my $job = shift;
    my $app = $job->app;

    my $m = 'YEARLY processing started';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    # reset traffic statistics
    my $r = eval { $app->mysql_inet->db->query("UPDATE devices SET sum_in = 0, sum_out = 0") };
    unless ($r) {
      $m = 'YEARLY archive SQL operation failed. Task stopped.';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);

      $job->fail;
      return;
    }

    $m = 'YEARLY processing finished';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $job->finish;
  });
}


1;
