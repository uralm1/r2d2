package Head::Command::statprocess;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::Util qw(getopt);

has description => '* Statistics processing: daily/monthly/yearly (run from cron cmd)';
has usage => "Usage: APPLICATION statprocess --daily|--monthly|--yearly\n";

sub run {
  my $app = shift->app;

  getopt \@_, 'cron'=>\my $cron,
    'daily|d'=>\my $op_daily,
    'monthly|m'=>\my $op_monthly,
    'yearly|y'=>\my $op_yearly
    or die "Bad argument. See statprocess --help.\n";

  my $id;
  $app->log->error('Warning! Execution subsystem unavailable.') unless $app->check_workers;

  if ($op_daily) {
    $id = $app->minion->enqueue('proc_daily');
    $app->log->info("DAILY statistics processing task $id was enqueued");

  } elsif ($op_monthly) {
    $id = $app->minion->enqueue('proc_monthly');
    $app->log->info("MONTHLY statistics processing task $id was enqueued");

  } elsif ($op_yearly) {
    $id = $app->minion->enqueue('proc_yearly');
    $app->log->info("YEARLY statistics processing task $id was enqueued");

  } else {
    die "No processing kind given. See statprocess --help.\n";
  }

  return 0;
}


1;
