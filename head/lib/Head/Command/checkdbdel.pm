package Head::Command::checkdbdel;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Head::Ural::CompatChk;
use Head::Ural::Profiles;

has description => '* Run check for database deletions (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdbdel\n";

sub run {
  my $app = shift->app;

  my $profiles = $app->profiles;

  my $dcc = $app->del_compat_check;
  return 1 unless $dcc;
  #$dcc->dump;

  $app->log->info('Checking db for deletions');
  $dcc->eachdel(sub {
    my ($id, $prof) = @_;
    #say "$id => $prof has been removed!";
    # loop by agents
    my $e = eval { $profiles->exist($prof) };
    if (!defined $e) {
      $app->log->error("Refresh failed: database error (exist)!");
    } elsif (!$e) {
      $app->log->error("Refresh deleted device id $id failed: invalid profile!");
    } else {
      my $res = eval { $profiles->eachagent($prof, sub {
        my ($profile_key, $agent_key, $agent) = @_;

        my $agent_url = $agent->{url};
        my $m = "REFRESH deleted device id $id $agent_url";
        $app->log->info($m);
        $app->dblog->info($m);

        $app->refresh_id($agent_url, $id);
      }) };
      $app->log->error("Refresh failed, database error (eachagent)!") unless $res;
    }

  })->update();

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}


1;
