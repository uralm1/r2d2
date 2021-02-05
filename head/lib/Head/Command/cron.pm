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

  my $sch = $app->config('stat_schedules');
  $sch = {} if (!$sch || ref($sch) ne 'HASH');
  $sch->{checkdb} = $app->config('check_compat_schedule');
  $sch->{checkdbdel} = $app->config('checkdel_compat_schedule');
  $sch->{truncatelog} = $app->config('logtruncate_schedule');

  my $xxx = {
    checkdb => { name=>'checkdb', cmd=>['checkdb'] },
    checkdbdel => { name=>'checkdbdel', cmd=>['checkdbdel'] },
    truncatelog => { name=>'truncatelog', cmd=>['truncatelog'] },
    daily => { name=>'stat daily', cmd=>[statprocess => '--daily'] },
    monthly => { name=>'stat monthly', cmd=>[statprocess => '--monthly'] },
    yearly => { name=>'stat yearly', cmd=>[statprocess => '--yearly'] },
  };

  my $b = 0;
  $b ||= $sch->{$_} for (keys %$xxx);
  unless ($b) {
    $log->warn('All config schedule parameters are undefined or empty. Scheduler process will exit.');
    return 0;
  }

  $log->info('Internal scheduler process started.');

  # use Poll reactor to catch signals, or we have to call EV::Signal to install signals into EV
  Mojo::IOLoop->singleton->reactor(Mojo::Reactor::Poll->new);

  local $SIG{INT} = local $SIG{TERM} = sub { Mojo::IOLoop->stop };

  Mojo::IOLoop->next_tick(sub {
    $self->_cron($sch->{$_},
      $xxx->{$_}{name},
      @{$xxx->{$_}{cmd}}
    ) for (sort keys %$xxx);
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
