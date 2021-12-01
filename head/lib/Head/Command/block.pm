package Head::Command::block;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;

has description => '* Run block check process (run from cron cmd)';
has usage => "Usage: APPLICATION block\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $db = $app->mysql_inet->db;

  $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;

  $app->log->info('Block devices - checking db');

  my ($selected, $notified, $blocked) = (0, 0, 0); # counters

  my $block_results = eval { $db->query("SELECT d.id, qs, c.email_notify, notified, profile \
FROM devices d INNER JOIN clients c ON d.client_id = c.id \
WHERE blocked = 0 AND sum_limit_in <= 0 AND qs > 0") };
  unless ($block_results) {
    $app->log->error("Block: database operation error: $@");
  } else {
    while (my $n = $block_results->hash) {
      $selected++;
      my $id = $n->{id};
      my $qs = $n->{qs};
      if ($qs == 1) {
        # warn(1) device
        if ($n->{email_notify} && !$n->{notified}) {
          $app->log->debug("Device to notify: $id, qs: $qs, $n->{profile}");
          $app->minion->enqueue(notify_client => [$id]);
          $notified++;
        }

      } elsif ($qs == 2 || $qs == 3) {
        # limit(2) or block(3) device
        $app->log->debug("Device to block: $id, qs: $qs, $n->{profile}");
        $app->minion->enqueue(block_client => [$id, $qs, $n->{profile}]);
        $blocked++;

      } else {
        $app->log->error("Unsupported qs $qs for device id $id.");
      }
    } # loop by devices
  }

  return "$selected/$notified/$blocked";
}

1;
