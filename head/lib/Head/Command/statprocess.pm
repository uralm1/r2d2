package Head::Command::statprocess;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::mysql;

has description => '* Statistics processing: daily/monthly/yearly (run from cron cmd)';
has usage => "Usage: APPLICATION statprocess --daily|--monthly|--yearly\n";

sub run {
  my ($self, $op) = @_;
  $op //= '';

  if ($op eq '-d' || $op eq '--daily') {
    $self->do_daily;
  } elsif ($op eq '-m' || $op eq '--monthly') {
    $self->do_monthly;
  } elsif ($op eq '-y' || $op eq '--yearly') {
    $self->do_yearly;
  } else {
    die "Bad argument. See statprocess --help.\n";
  }

  return 0;
}


sub do_daily {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'DAILY';
  $self->_startup($procstr);

  # archive traffic statistics
  my $r = eval { $app->mysql_inet->db->query("INSERT INTO adaily (client_id, login, date, d_in, d_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE d_in = sum_in, d_out = sum_out") };
  unless ($r) {
    my $m = 'Daily archive SQL operation failed.';
    $app->log->error($m." $@");
    $app->dblog->error($m, sync=>1);
  }

  $self->_finish($procstr);
}


sub do_monthly {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'MONTHLY';
  $self->_startup($procstr);

  my $db = $app->mysql_inet->db;

  # archive traffic statistics
  my $r = eval { $db->query("INSERT INTO amonthly (client_id, login, date, m_in, m_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE m_in = sum_in, m_out = sum_out") };
  unless ($r) {
    my $m = 'Monthly archive SQL operation failed.';
    $app->log->error($m." $@");
    $app->dblog->error($m, sync=>1);
  }

  # restore limits
  my $m = 'Restoring quota limits and notifications.';
  $app->log->info($m);
  $app->dblog->info($m, sync=>1);

  $r = eval { $db->query("UPDATE clients SET sum_limit_in = limit_in, blocked = 0, notified = 0") };
  unless ($r) {
    $m = 'Restoring quota limits/notifications failed.';
    $app->log->error($m." $@");
    $app->dblog->error($m, sync=>1);
  }

  # reset notification flags
  $m = 'Resetting notification flags (oldcompat).';
  $app->log->info($m);
  $app->dblog->info($m, sync=>1);

  $r = eval { $db->query("UPDATE clients_sync SET email_notified = 0") };
  unless ($r) {
    $m = 'Resetting notification flags failed.';
    $app->log->error($m." $@");
    $app->dblog->error($m, sync=>1);
  }

  $self->_finish($procstr);
}


sub do_yearly {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'YEARLY';
  $self->_startup($procstr);

  # reset traffic statistics
  my $r = eval { $app->mysql_inet->db->query("UPDATE clients SET sum_in = 0, sum_out = 0") };
  unless ($r) {
    my $m = 'Yearly archive SQL operation failed.';
    $app->log->error($m." $@");
    $app->dblog->error($m, sync=>1);
  }

  $self->_finish($procstr);
}


sub _startup {
  my ($self, $procstr) = @_;
  my $app = $self->app;

  my $m = "$procstr processing started.";
  $app->log->info($m);
  $app->dblog->info($m, sync=>1);
}

sub _finish {
  my ($self, $procstr) = @_;
  my $app = $self->app;

  my $m = "$procstr processing finished.";
  $app->log->info($m);
  $app->dblog->info($m, sync=>1);
}


1;
