package Head::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Head::Ural::Profiles;

has description => '* Run check for database changes (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $app = shift->app;

  my $profiles = $app->profiles(dont_copy_config_to_db => 1);
  my $db = $app->mysql_inet->db;
  $app->log->info('Asyncronious update - checking db for changes');
  $db->query("SELECT id, profile, sync_flags FROM devices WHERE sync_flags > 0" =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        # loop by devices
        while (my $n = $results->hash) {
          my $id = $n->{id};
          my $sync_flags = $n->{sync_flags};
          my $sync_rt = ($sync_flags & 0b1000) >> 3;
          my $sync_fw = ($sync_flags & 0b0100) >> 2;
          my $sync_dhcp = $sync_flags & 0b0011;
          my %oldflags = (rtsyn=>$sync_rt, dhcpsyn=>$sync_dhcp, fwsyn=>$sync_fw);

          #say "id: $id, profile: $n->{profile}";
          # loop by agents
          my $res = $profiles->eachagent($n->{profile}, sub {
            my ($profile_key, $agent_key, $agent) = @_;

            my $agent_type = $agent->{type};

            if (exists $oldflags{$agent_type}) {
              # rtsyn/dhcpsyn/fwsyn use the only corresponding flag
              $app->refresh_id($agent->{url}, $id) if $oldflags{$agent_type};
            } else {
              # gwsyn and others use any of the flags
              $app->refresh_id($agent->{url}, $id);
            }

          });
          $app->log->error("Refresh device id $id failed: invalid profile!") unless $res;

        } # while
      } else {
        $app->log->error('Device refresh: database operation error.');
      }
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}


1;
