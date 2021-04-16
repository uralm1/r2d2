package Head::Command::statprocess;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Statistics processing: daily/monthly/yearly (run from cron cmd)';
has usage => "Usage: APPLICATION statprocess --daily|--monthly|--yearly\n";

sub run {
  my ($self, $op) = @_;
  $op //= '';

  my $app = $self->app;
  my $id;

  if ($op eq '-d' || $op eq '--daily') {
    $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;
    $id = $app->minion->enqueue('proc_daily');
    $app->log->info("DAILY statistics processing task $id was enqueued");

  } elsif ($op eq '-m' || $op eq '--monthly') {
    $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;
    $id = $app->minion->enqueue('proc_monthly');
    $app->log->info("MONTHLY statistics processing task $id was enqueued");

  } elsif ($op eq '-y' || $op eq '--yearly') {
    $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;
    $id = $app->minion->enqueue('proc_yearly');
    $app->log->info("YEARLY statistics processing task $id was enqueued");

  } else {
    die "Bad argument. See statprocess --help.\n";
  }

  return 0;
}


1;
