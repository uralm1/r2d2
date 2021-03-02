package Head::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Manually refresh client by <id>';
has usage => "Usage: APPLICATION refresh <client-id>\n";

sub run {
  my ($self, $id) = @_;
  my $app = $self->app;
  die "Bad <client-id> argument.\n" unless (defined($id) && $id =~ /^\d+$/);

  my $profiles = $app->config('profiles');
  my $dbconn = $app->mysql_inet->db;
  $app->log->info('Asyncronious refresh initiated');
  $dbconn->query("SELECT profile FROM clients WHERE id = ?", $id =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        my $n = $results->hash;
        #say "profile: $n->{profile}";
        if (my $profile = $profiles->{$n->{profile}}) {
          # loop by agents
          for my $agent (@{$profile->{agents}}) {

            $app->refresh_id($agent->{url}, $id);

          }
        } else {
          $app->log->error("Refresh client id $id failed: invalid profile!");
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
