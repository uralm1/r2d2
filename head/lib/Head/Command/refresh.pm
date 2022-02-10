package Head::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw(getopt);
use Head::Ural::Profiles;
#use Carp;

has description => '* Manually refresh device by <id>';
has usage => "Usage: APPLICATION refresh <device-id>\n";

sub run {
  my $app = shift->app;

  #getopt \@_, 'cron'=>\my $cron
  #  or die "Error in commandline arguments\n";

  my ($id) = @_;
  die "Bad <device-id> argument.\n" unless (defined($id) && $id =~ /^\d+$/);

  my $profiles = $app->profiles;
  my $db = $app->mysql_inet->db;
  $app->log->info('Asyncronious refresh initiated');
  $db->query("SELECT profile FROM devices WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        my $n = $results->hash;
        #say "profile: $n->{profile}";
        # loop by agents
        if ($profiles->exist($n->{profile})) {
          my $res = $profiles->eachagent($n->{profile}, sub {
            my ($profile_key, $agent_key, $agent) = @_;

            $app->refresh_id($agent->{url}, $id);

          });
          $app->log->error("Refresh failed, database error!") unless $res;

        } else {
          $app->log->error("Refresh device id $id failed: invalid profile!");
        }

      } else {
        $app->log->error('Device refresh: database operation error.');
      }
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}

1;
