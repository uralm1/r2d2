package Master::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

use Master::Ural::Rtref qw(rtsyn_refresh_id);
use Carp;

has description => '* Manually refresh client by id';
has usage => "Usage: APPLICATION refresh <client-id>\n";

sub run {
  my ($self, $id) = @_;
  my $app = $self->app;
  croak("Bad <client-id> argument\n") unless (defined($id) && $id =~ /^\d+$/);

  my $profiles = $app->config('profiles');
  my $dbconn = $app->mysql_inet->db;
  $app->log->info('Asyncronious refresh initiated');
  $dbconn->query("SELECT profile_id FROM clients WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        my $n = $results->hash;
        #say "profile_id: $n->{profile_id}";
        if (my $profile = $profiles->{$n->{profile_id}}) {
          # loop by agents
          for my $agent (@{$profile->{agents}}) {
            my $agent_type = $agent->{type};
            my $agent_url = $agent->{url};
            if ($agent_type eq 'rtsyn') {
              $app->log->info("Client id $id refreshing $agent_type\@[$agent_url]");
              rtsyn_refresh_id($app, $dbconn, $id, $agent_url);
            } elsif ($agent_type eq 'dhcpsyn') {
              $app->log->info("Client id $id refreshing $agent_type\@[$agent_url]");
              #TODO
            } elsif ($agent_type eq 'fwsyn') {
              $app->log->info("Client id $id refreshing $agent_type\@[$agent_url]");
              #TODO
            } else {
              $app->log->warn("Client id $id refresh unsupported agent!");
            }
          }
        } else {
          $app->log->error("Client id $id refresh failed invalid profile!");
        }
      } else {
        $app->log->error('Client refresh: database operation error.');
      }
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}

1;
