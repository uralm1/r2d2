package Master::Command::checkdb;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Master::Ural::Dblog;
use Master::Ural::Rtref qw(rtsyn_refresh_id);

has description => '* Run check for database changes manually';
has usage => "Usage: APPLICATION checkdb\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $profiles = $app->config('profiles');
  my $dbconn = $app->mysql_inet->db;
  $app->log->info('Asyncronious update initiated');
  $dbconn->query("SELECT clients.id, profile_id, s.sync_rt, s.sync_fw, s.sync_dhcp FROM clients, clients_sync s\
WHERE (s.sync_rt = 1 OR s.sync_fw = 1 OR s.sync_dhcp = 1) AND clients.login = s.login" =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        # loop by clients
        while (my $n = $results->hash) {
          my $id = $n->{id};

          #say "id: $id, profile_id: $n->{profile_id}";
          my $profile = $profiles->{$n->{profile_id}};
          if ($profile) {
            # loop by agents
            for my $agent (@{$profile->{agents}}) {
              my $agent_type = $agent->{type};
              my $agent_url = $agent->{url};
              if ($agent_type eq 'rtsyn' && $n->{sync_rt}) {
                $app->log->info("Client id $id refreshing $agent_type\@$agent_url");
                rtsyn_refresh_id($app, $dbconn, $id, $agent_url);
              } elsif ($agent_type eq 'dhcpsyn' && $n->{sync_dhcp}) {
                $app->log->info("Client id $id refreshing $agent_type\@$agent_url");
                #TODO
              } elsif ($agent_type eq 'fwsyn' && $n->{sync_fw}) {
                $app->log->info("Client id $id refreshing $agent_type\@$agent_url");
                #TODO
              } else {
                $app->log->warn("Client id $id refresh unsupported agent!");
              }
            }
          } else {
            $app->log->error("Client id $id refresh failed invalid profile!");
          }
        } # while
      } else {
        $app->log->error('Client refresh: database operation error.');
      }
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}


1;
