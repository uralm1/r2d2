package Head::Task::ProcMonthly;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
use Mojo::URL;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(proc_monthly => sub {
    my $job = shift;
    my $app = $job->app;

    my $m = 'MONTHLY processing started';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    my $error = 0;
    my $db = $app->mysql_inet->db;

    # archive traffic statistics
    my $r = eval { $db->query("INSERT INTO amonthly (client_id, login, date, m_in, m_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE m_in = sum_in, m_out = sum_out") };
    unless ($r) {
      $m = 'MONTHLY archive SQL operation failed';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);
      $error = 1;
    }

    # restore limits
    $m = 'Restoring quota limits and notifications';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $r = eval { $db->query("UPDATE clients SET sum_limit_in = limit_in, blocked = 0, notified = 0") };
    unless ($r) {
      $m = 'Restoring quota limits/notifications failed';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);
      $error = 1;
    }

    # reset notification flags
    $m = 'Resetting notification flags (oldcompat)';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $r = eval { $db->query("UPDATE clients_sync SET email_notified = 0") };
    unless ($r) {
      $m = 'Resetting notification flags failed';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);
    }

    # send RELOAD to all block agents to unblock clients in one request
    while (my ($p, $pv) = each @{$app->config('profiles')}) {
    LOOP_AGENTS:
      for my $agent (@{$pv->{agents}}) {
        next LOOP_AGENTS unless $agent->{block};

        my $agent_url = $agent->{url};
        my $agent_type = $agent->{type};
        # send reload to agent
        $m = "Reloading agent $agent_type [$agent_url]";
        $app->log->info($m);
        $app->dblog->info($m, sync=>1);

        $r = eval {
          $app->ua->post(Mojo::URL->new("$agent_url/reload"))->result;
        };
        unless (defined $r) {
          # connection to agent failed
          $m = "Connection to agent $agent_type [$agent_url] failed";
          $app->log->error($m.": $@");
          $app->dblog->error($m, sync=>1);

        } else {
          if ($r->is_success) {
            # successful reload
            $m = "Agent $agent_type [$agent_url] reload request successfully sent";
            $app->log->info($m);
            $app->dblog->info($m, sync=>1);
          } else {
            # request error 503
            if ($r->is_error) {
              $m = "Agent $agent_type [$agent_url] reload error: ".$r->body;
              $app->log->error($m);
              $app->dblog->error($m, sync=>1);
            }
          }

        }
      } # agents loop
    } # profiles loop

    $m = 'MONTHLY processing finished'.($error) ? ' (FAILED with ERRORS)' : '';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $error ? $job->fail : $job->finish;
  });
}


1;
