package Head::Command::checkdbdel;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Head::Ural::CompatChk;

has description => '* Run check for database deletions (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdbdel\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $profiles = $app->config('profiles');

  my $dcc = $app->del_compat_check;
  return 1 unless $dcc;
  #$dcc->dump;

  $app->log->info('Checking db for deletions');
  $dcc->eachdel(sub {
    my ($id, $prof) = @_;
    #say "$id => $prof has been removed!";
    if (my $profile = $profiles->{ $prof }) {
      # loop by agents
      for my $agent (@{$profile->{agents}}) {
        my $agent_url = $agent->{url};
        my $m = "REFRESH deleted client id $id $agent_url";
        $app->log->info($m);
        $app->dblog->info($m);

        $app->refresh_id($agent_url, $id);
      }

    } else {
      $app->log->error("Refresh deleted client id $id failed: invalid profile!");
    }
  })->update();

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}


1;
