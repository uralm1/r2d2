package Head::Task::BlockClient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(block_client => sub {
    my ($job, $id, $qs, $profile) = @_;
    die 'Bad job parameters' unless $id && defined $qs && $profile;

    my $app = $job->app;
    my $profiles = $app->config('profiles');

    if (my $p = $profiles->{$profile}) {
      # loop by agents
      for my $agent (@{$p->{agents}}) {
        next unless $agent->{block};

        my $agent_url = $agent->{url};
        # send block to agent
        my $m = (($qs == 0) ? 'UNBLOCK' : 'BLOCK')." device id $id, op $qs [$agent_url]";
        $app->log->info($m);
        $app->dblog->info($m, sync=>1);

        my $r = eval {
          $app->ua->post(Mojo::URL->new("$agent_url/block/$id/$qs"))->result;
        };
        unless (defined $r) {
          # connection to agent failed
          $app->log->error("Connection to agent [$agent_url] failed: $@");
          $app->dblog->error("Device id $id error: connection to agent [$agent_url] failed", sync=>1);
        } else {
          if ($r->is_success) {
            # successful update
            my $m = "Device id $id block/unblock request successfully received by agent [$agent_url]".($r->body ? ': '.$r->body : '');
            $app->log->info($m);
            $app->dblog->info($m, sync=>1);

          } else {
            # request error 503
            if ($r->is_error) {
              my $m = "Device id $id error: ".$r->body;
              $app->log->error($m);
              $app->dblog->error($m, sync=>1);
            }
          }
        }
      } # agents loop

    } else {
      my $m = "Blocking/Unblocking device id $id failed: invalid profile!";
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
    }

    $job->finish;
  });
}


1;
