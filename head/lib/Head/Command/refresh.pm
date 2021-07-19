package Head::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Manually refresh device by <id>';
has usage => "Usage: APPLICATION refresh <device-id>\n";

sub run {
  my ($self, $id) = @_;
  my $app = $self->app;
  die "Bad <device-id> argument.\n" unless (defined($id) && $id =~ /^\d+$/);

  my $profiles = $app->config('profiles');
  my $dbconn = $app->mysql_inet->db;
  $app->log->info('Asyncronious refresh initiated');
  $dbconn->query("SELECT profile FROM devices WHERE id = ?", $id =>
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
