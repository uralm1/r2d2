package Gwsyn::Command::cron;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::IOLoop;
use Mojo::Log;
use Algorithm::Cron;

has description => '* Run builtin internal scheduler /REQUIRED/';
has usage => "Usage: APPLICATION cron\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  binmode(STDOUT, ':utf8');
  #binmode(STDERR, ':utf8');

  my $traf_sch = $app->config('trafstat_schedule');
  if (!$traf_sch) {
    my $m = 'Config parameters trafstat_schedule is undefined or empty. Scheduler process will exit.';
    $app->rlog($m);
    $app->log->info($m) unless $app->config('rlog_local');
    return 0;
  }

  my $m = 'Internal scheduler process started.';
  $app->rlog($m);
  $app->log->info($m) unless $app->config('rlog_local');

  # use Poll reactor to catch signals, or we have to call EV::Signal to install signals into EV
  Mojo::IOLoop->singleton->reactor(Mojo::Reactor::Poll->new);

  local $SIG{INT} = local $SIG{TERM} = sub { Mojo::IOLoop->stop };

  Mojo::IOLoop->next_tick(sub {
    $self->_cron($traf_sch, 'trafstat', 'trafstat');
  });

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  $m = 'Internal scheduler finished.';
  $app->rlog($m);
  $app->log->info($m) unless $app->config('rlog_local');
}

sub _cron() {
  my ($self, $crontab, $name, @cmd) = @_;
  my $app = $self->app;
  carp "Bad $name crontab" unless $crontab;

  my $cron = Algorithm::Cron->new(
    base => 'local',
    crontab => $crontab,
  );
  $app->rlog("Schedule ($name: \"$crontab\") active.");

  my $time = time;
  # $cron, $time goes to closure
  my $task;
  $task = sub {
    $time = $cron->next_time($time);
    while ($time - time <= 0) {
      #say "Time diff negative!";
      $time = $cron->next_time($time);
    }
    Mojo::IOLoop->timer(($time - time) => sub {
      $app->rlog("EVENT from schedule ($name) started.");
      my $e = eval { $self->app->commands->run(@cmd) };
      my $es = (defined $e) ? "code: $e":"with error: $@";
      $app->rlog("EVENT from schedule ($name) finished $es.");
      $task->();
    });
  };
  $task->();
}

#-------------------------------------------------

1;
