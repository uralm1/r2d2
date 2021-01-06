package Head::Command::statprocess;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::mysql;
use Head::Ural::Dblog;

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
    croak "Bad argument. See statprocess --help.\n";
  }

  return 0;
}


sub do_daily {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'Daily';
  $self->_startup($procstr);

  # archive traffic statistics
  $app->mysql_inet->db->query("INSERT INTO adaily (login, date, d_in, d_out) \
SELECT login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE d_in = sum_in, d_out = sum_out" =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        my $m = 'Daily archive SQL operation failed.';
        $app->log->error($m);
        $app->defaults('dblog')->l(info=>$m);
      }
      $self->_finish($procstr);
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


sub do_monthly {
  my $self = shift;
  my $app = $self->app;
  my $dblog = $app->defaults('dblog');
  my $procstr = 'Monthly';
  $self->_startup($procstr);

  my $db = $app->mysql_inet->db;
  Mojo::IOLoop->delay(
    # archive traffic statistics
    sub {
      my $delay = shift;
      $db->query("INSERT INTO amonthly (login, date, m_in, m_out) \
SELECT login, CURDATE(), sum_in, sum_out \
FROM clients \
ON DUPLICATE KEY UPDATE m_in = sum_in, m_out = sum_out" =>  $delay->begin);
    },
    sub {
      my ($delay, $err, $results) = @_;
      if ($err) {
        my $m = 'Monthly archive SQL operation failed.';
        $app->log->error($m);
        $dblog->l(info=>$m);
      }
      $delay->pass;
    },

    # restore limits
    sub {
      my $delay = shift;
      my $m = 'Restoring quota limits.';
      $app->log->info($m);
      $dblog->l(info=>$m);

      $db->query("UPDATE clients SET sum_limit_in = limit_in" => $delay->begin);
    },
    sub {
      my ($delay, $err, $results) = @_;
      if ($err) {
        my $m = 'Restoring quota limits failed.';
        $app->log->error($m);
        $dblog->l(info=>$m);
      }
      $delay->pass;
    },

    # reset notification flags
    sub {
      my $delay = shift;
      my $m = 'Resetting notification flags.';
      $app->log->info($m);
      $dblog->l(info=>$m);

      $db->query("UPDATE clients_sync SET email_notified = 0" => $delay->begin);
    },
    sub {
      my ($delay, $err, $results) = @_;
      if ($err) {
        my $m = 'Resetting notification flags failed.';
        $app->log->error($m);
        $dblog->l(info=>$m);
      }
      $self->_finish($procstr);
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


sub do_yearly {
  my $self = shift;
  my $app = $self->app;
  my $procstr = 'Yearly';
  $self->_startup($procstr);

  # archive traffic statistics
  $app->mysql_inet->db->query("UPDATE clients SET sum_in = 0, sum_out = 0" =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        my $m = 'Yearly archive SQL operation failed.';
        $app->log->error($m);
        $app->defaults('dblog')->l(info=>$m);
      }
      $self->_finish($procstr);
    }
  );

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


sub _startup {
  my ($self, $procstr) = @_;
  my $app = $self->app;

  my $m = "$procstr processing started.";
  $app->log->info($m);
  $app->defaults('dblog')->l(info=>$m);
}

sub _finish {
  my ($self, $procstr) = @_;
  my $app = $self->app;

  my $m = "$procstr processing finished.";
  $app->log->info($m);
  $app->defaults('dblog')->l(info=>$m);
}


1;
