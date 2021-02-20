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
  my $p = $app->mysql_inet->db->query_p("INSERT INTO adaily (client_id, login, date, d_in, d_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE d_in = sum_in, d_out = sum_out");
  $p->catch(sub {
    my $err = shift;
    my $m = 'Daily archive SQL operation failed.';
    $app->log->error($m." $err");
    $app->dblog->error($m);

  })->finally(sub {
    $self->_finish($procstr);

  })->wait;
}


sub do_monthly {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'MONTHLY';
  $self->_startup($procstr);

  my $db = $app->mysql_inet->db;

  # archive traffic statistics
  my $p = $db->query_p("INSERT INTO amonthly (client_id, login, date, m_in, m_out) \
SELECT id, login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE m_in = sum_in, m_out = sum_out");
  $p->catch(sub {
    my $err = shift;
    my $m = 'Monthly archive SQL operation failed.';
    $app->log->error($m." $err");
    $app->dblog->error($m);

  })->then(sub {
    # restore limits
    my $m = 'Restoring quota limits.';
    $app->log->info($m);
    $app->dblog->info($m);

    return $db->query_p("UPDATE clients SET sum_limit_in = limit_in");
  })->catch(sub {
    my $err = shift;
    my $m = 'Restoring quota limits failed.';
    $app->log->error($m." $err");
    $app->dblog->error($m);

  })->then(sub {
    # reset notification flags
    my $m = 'Resetting notification flags.';
    $app->log->info($m);
    $app->dblog->error($m);

    return $db->query_p("UPDATE clients_sync SET email_notified = 0");
  })->catch(sub {
    my $err = shift;
    my $m = 'Resetting notification flags failed.';
    $app->log->error($m." $err");
    $app->dblog->error($m);

  })->finally(sub {
    $self->_finish($procstr);

  })->wait;
}


sub do_yearly {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'YEARLY';
  $self->_startup($procstr);

  # reset traffic statistics
  my $p = $app->mysql_inet->db->query_p("UPDATE clients SET sum_in = 0, sum_out = 0");
  $p->catch(sub {
    my $err = shift;
    my $m = 'Yearly archive SQL operation failed.';
    $app->log->error($m." $err");
    $app->dblog->error($m);

  })->finally(sub {
    $self->_finish($procstr);

  })->wait;
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
