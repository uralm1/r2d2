package Head::Command::block;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::IOLoop;

has description => '* Run blocking/unblocking process (run from cron cmd)';
has usage => "Usage: APPLICATION block\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $dbconn = $app->mysql_inet->db;

  $app->log->info('Block clients - checking db');
  my $block_results = eval { $dbconn->query("SELECT id, qs, notified, profile FROM clients \
WHERE blocked = 0 AND sum_limit_in <= 0 AND qs > 0") };
  unless ($block_results) {
    $app->log->error("Block: database operation error: $@");
  } else {
    while (my $n = $block_results->hash) {
      my $id = $n->{id};
      my $qs = $n->{qs};
      if ($qs == 1) {
        # warn(1) client
        $app->log->debug("Client to notify: $id, qs: $qs, $n->{profile}");
        $app->minion->enqueue(notify_client => [$id, $qs]) unless $n->{notified};

      } elsif ($qs == 2 || $qs == 3) {
        # limit(2) or block(3) client
        $app->log->debug("Client to block: $id, qs: $qs, $n->{profile}");
        $app->minion->enqueue(block_client => [$id, $qs, $n->{profile}, $n->{notified} ? 0 : 1]);

      } else {
        $app->log->error("Unsupported qs $qs for client id $id.");
      }
    } # loop by clients
  }

  $app->log->info('Unblock clients - checking db');
  my $unblock_results = eval { $dbconn->query("SELECT id, profile FROM clients \
WHERE blocked = 1 AND (sum_limit_in > 0 OR qs = 0 OR qs = 1)") };
  unless ($unblock_results) {
    $app->log->error("Unblock: database operation error: $@");
  } else {
    while (my $n = $unblock_results->hash) {
      $app->log->debug("Client to unblock: $n->{id}, $n->{profile}");
      # unblock, don't notify
      $app->minion->enqueue(block_client => [$n->{id}, 0, $n->{profile}]);
    } # loop by clients
  }


  return 1;
}

1;
