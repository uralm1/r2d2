package Head::Task::ProcMonthly;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
use Mojo::URL;
use Head::Ural::Profiles;
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
    my $r = eval { $db->query("INSERT INTO amonthly (device_id, date, m_in, m_out) \
SELECT id, CURDATE(), sum_in, sum_out \
FROM devices \
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

    $r = eval { $db->query("UPDATE devices SET sum_limit_in = limit_in, blocked = 0, notified = 0") };
    unless ($r) {
      $m = 'Restoring quota limits/notifications failed';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);
      $error = 1;
    }

    # send RELOAD to all block agents to unblock devices in one request
    $r = eval { $app->profiles->eachagent(sub {
      my ($profile_key, $agent_key, $agent) = @_;

      return unless $agent->{block};

      my $agent_url = $agent->{url};
      my $agent_type = $agent->{type};
      # send reload to agent
      $m = "Reloading profile $profile_key, agent $agent_type [$agent_url]";
      $app->log->info($m);
      $app->dblog->info($m, sync=>1);

      my $r1 = eval {
        $app->ua->post(Mojo::URL->new("$agent_url/reload"))->result;
      };
      unless (defined $r1) {
        # connection to agent failed
        $m = "Connection to agent $agent_type [$agent_url] failed";
        $app->log->error($m.": $@");
        $app->dblog->error($m, sync=>1);

      } else {
        if ($r1->is_success) {
          # successful reload
          $m = "Agent $agent_type [$agent_url] reload request successfully sent";
          $app->log->info($m);
          $app->dblog->info($m, sync=>1);
        } else {
          # request error 503
          if ($r1->is_error) {
            $m = "Agent $agent_type [$agent_url] reload error: ".$r1->body;
            $app->log->error($m);
            $app->dblog->error($m, sync=>1);
          }
        }

      }
    }) };
    unless ($r) {
      $m = 'Unblocking blocked devices failed (eachagent)';
      $app->log->error($m.": $@");
      $app->dblog->error($m, sync=>1);
      $error = 1;
    }

    $m = 'MONTHLY processing finished'.($error) ? ' (FAILED with ERRORS)' : '';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $error ? $job->fail : $job->finish;
  });
}


1;
