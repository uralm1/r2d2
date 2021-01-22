package Head::Command::cron;
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
  my $log = $app->log;

  binmode(STDOUT, ':utf8');
  #binmode(STDERR, ':utf8');

  my $check_sch = $app->config('check_schedule');
  my $log_sch = $app->config('logrotate_schedule');
  my $sch = $app->config('stat_schedules');
  if (!$check_sch && !$log_sch && (!$sch || ref($sch) ne 'HASH')) {
    $log->warn('Config parameters *_schedules are undefined or empty. Scheduler process will exit.');
    return 0;
  }
  if (!$check_sch && !$log_sch && !$sch->{daily} && !$sch->{monthly} && !$sch->{yearly}) {
    $log->warn('All config schedule parameters are undefined or empty. Scheduler process will exit.');
    return 0;
  }
  $sch->{checkdb} = $check_sch;
  $sch->{rotatelog} = $log_sch;

  $log->info('Internal scheduler process started.');

  # use Poll reactor to catch signals, or we have to call EV::Signal to install signals into EV
  Mojo::IOLoop->singleton->reactor(Mojo::Reactor::Poll->new);

  local $SIG{INT} = local $SIG{TERM} = sub { Mojo::IOLoop->stop };

  Mojo::IOLoop->next_tick(sub {
    $self->_cron($sch->{$_},
      ($_ eq 'checkdb' || $_ eq 'rotatelog')?$_ : "stat $_",
      ($_ eq 'checkdb' || $_ eq 'rotatelog')?$_ : (statprocess => "--$_")) for(qw/checkdb rotatelog daily monthly yearly/);
  });

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  $log->info('Internal scheduler finished.');
}

sub _cron() {
  my ($self, $crontab, $name, @cmd) = @_;
  my $log = $self->app->log;
  carp "Bad $name crontab" unless $crontab;

  my $cron = Algorithm::Cron->new(
    base => 'local',
    crontab => $crontab,
  );
  $log->info("Schedule ($name: \"$crontab\") active.");

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
      $log->info("EVENT from schedule ($name) started.");
      my $e = eval { $self->app->commands->run(@cmd) };
      my $es = (defined $e) ? "code: $e":"with error: $@";
      $log->info("EVENT from schedule ($name) finished $es.");
      $task->();
    });
  };
  $task->();
}

#-------------------------------------------------

1;
