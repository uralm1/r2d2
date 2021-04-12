package Head::Command::block;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::IOLoop;

has description => '* Run blocking/unblocking process (run from cron cmd)';
has usage => "Usage: APPLICATION block\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $profiles = $app->config('profiles');

  my $dbconn = $app->mysql_inet->db;

  $app->log->info('Block clients - checking db');
  my $block_results = eval { $dbconn->query("SELECT id, login, qs, notified, profile FROM clients \
WHERE blocked = 0 AND sum_limit_in <= 0 AND qs > 0") };
  unless ($block_results) {
    $app->log->error("Block: database operation error: $@");
  } else {
    while (my $n = $block_results->hash) {
      my $qs = $n->{qs};
      if ($qs == 1) {
        # warn(1) client
        $app->log->debug("Client to notify: $n->{id}, $n->{login}, qs: $qs, $n->{profile}");
        # TODO
      } elsif ($qs == 2 || $qs == 3) {
        # limit(2) or block(3) client
        $app->log->debug("Client to block: $n->{id}, $n->{login}, qs: $qs, $n->{profile}");

        if (my $profile = $profiles->{$n->{profile}}) {
          # loop by agents
          for my $agent (@{$profile->{agents}}) {
            next unless $agent->{block};
            $app->log->debug("TODO Send block to agent: $agent->{type}, $agent->{url}");
            # TODO
          }

        } else {
          $app->log->error("Blocking client id $n->{id} failed: invalid profile!");
        }
      } else {
        $app->log->error("Unsupported qs $qs for client id $n->{id}.");
      }
    } # loop by clients
  }

  $app->log->info('Unblock clients - checking db');
  my $unblock_results = eval { $dbconn->query("SELECT id, login, profile FROM clients \
WHERE blocked = 1 AND (sum_limit_in > 0 OR qs = 0 OR qs = 1)") };
  unless ($unblock_results) {
    $app->log->error("Unblock: database operation error: $@");
  } else {
    while (my $n = $unblock_results->hash) {
      $app->log->debug("Client to unblock: $n->{id}, $n->{login}, $n->{profile}");

      if (my $profile = $profiles->{$n->{profile}}) {
        # loop by agents
        for my $agent (@{$profile->{agents}}) {
          next unless $agent->{block};
          $app->log->debug("TODO Send unblock to agent: $agent->{type}, $agent->{url}");
          # TODO
        }

      } else {
        $app->log->error("Unblocking client id $n->{id} failed: invalid profile!");
      }
    } # loop by clients
  }


  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 1;
}

1;
