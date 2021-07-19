package Head::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Run check for database changes (run from cron cmd, compatibility)';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $profiles = $app->config('profiles');
  my $dbconn = $app->mysql_inet->db;
  $app->log->info('Asyncronious update - checking db for changes');
  $dbconn->query("SELECT devices.id, profile, s.sync_rt, s.sync_fw, s.sync_dhcp FROM devices, devices_sync s\
WHERE (s.sync_rt > 0 OR s.sync_fw > 0 OR s.sync_dhcp > 0) AND devices.login = s.login" =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        # loop by devices
        while (my $n = $results->hash) {
          my $id = $n->{id};
          my %oldflags = (rtsyn=>$n->{sync_rt}, dhcpsyn=>$n->{sync_dhcp}, fwsyn=>$n->{sync_fw});

          #say "id: $id, profile: $n->{profile}";
          if (my $profile = $profiles->{$n->{profile}}) {
            # loop by agents
            for my $agent (@{$profile->{agents}}) {
              my $agent_type = $agent->{type};

              if (exists $oldflags{$agent_type}) {
                # rtsyn/dhcpsyn/fwsyn use the only corresponding flag
                $app->refresh_id($agent->{url}, $id) if $oldflags{$agent_type};
              } else {
                # gwsyn and others use any of the flags
                $app->refresh_id($agent->{url}, $id);
              }

            }
          } else {
            $app->log->error("Refresh device id $id failed: invalid profile!");
          }
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
