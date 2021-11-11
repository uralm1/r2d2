package Head::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Head::Ural::Profiles;

has description => '* Run check for database changes (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $profiles = $app->profiles(dont_copy_config_to_db => 1);
  my $db = $app->mysql_inet->db;
  $app->log->info('Asyncronious update - checking db for changes');
  $db->query("SELECT devices.id, profile, s.sync_rt, s.sync_fw, s.sync_dhcp FROM devices, devices_sync s\
WHERE (s.sync_rt > 0 OR s.sync_fw > 0 OR s.sync_dhcp > 0) AND devices.login = s.login" =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        # loop by devices
        while (my $n = $results->hash) {
          my $id = $n->{id};
          my %oldflags = (rtsyn=>$n->{sync_rt}, dhcpsyn=>$n->{sync_dhcp}, fwsyn=>$n->{sync_fw});

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
