package Head::Task::BlockClient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Head::Ural::Profiles;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(block_client => sub {
    my ($job, $id, $qs, $profile) = @_;
    die 'Bad job parameters' unless $id && defined $qs && $profile;

    my $app = $job->app;

    # loop by agents
    my $e = eval { $app->profiles->exist($profile) };
    my $m = undef;
    $m = "Blocking/Unblocking device id $id failed: database error (exist)!" unless defined $e;
    $m = "Blocking/Unblocking device id $id failed: invalid profile!" unless $e;
    if ($m) {
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
      return $job->finish;
    }

    my $res = eval { $app->profiles->eachagent($profile, sub {
      my ($profile_key, $agent_key, $agent) = @_;

      return unless $agent->{block};

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
    }) };
    unless ($res) {
      my $m = "Blocking/Unblocking device id $id failed: database error (eachagent)!";
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
    }

    $job->finish;
  });
}


1;
