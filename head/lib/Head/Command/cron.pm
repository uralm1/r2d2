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

  my $_ss = $app->config('stat_schedules');
  $_ss = {} if (!$_ss || ref($_ss) ne 'HASH');

  my $tasks = [
    { name => 'checkdb',
      crontab => $app->config('check_compat_schedule'),
      cmd => ['checkdb']
    },
    { name => 'checkdbdel',
      crontab => $app->config('checkdel_compat_schedule'),
      cmd => ['checkdbdel']
    },
    { name => 'block',
      crontab => $app->config('block_schedule'),
      cmd => ['block']
    },
    { name => 'unblock',
      crontab => $app->config('unblock_schedule'),
      cmd => ['unblock']
    },
    { name => 'truncate log',
      crontab => $app->config('truncatelog_schedule'),
      task => ['truncatelog']
    },
    { name => 'connectivity',
      crontab => $app->config('connectivity_schedule'),
      task => ['connectivity']
    },
    { name => 'check clients',
      crontab => $app->config('checkclients_schedule'),
      task => ['check_clients']
    },
    { name => 'stat daily',
      crontab => $_ss->{daily},
      cmd => [statprocess => '--daily']
    },
    { name => 'stat monthly',
      crontab => $_ss->{monthly},
      cmd => [statprocess => '--monthly']
    },
    { name => 'stat yearly',
      crontab => $_ss->{yearly},
      cmd => [statprocess => '--yearly']
    },
  ];

  my $b = 0;
  for (@$tasks) {
    $b ||= $_->{crontab};
    $log->warn("Task $_->{name} has both cmd and task parameters defined. Only task parameter will be used.")
      if defined $_->{cmd} && defined $_->{task};
  }
  unless ($b) {
    $log->warn('All config schedule parameters are undefined or empty. Scheduler process will exit.');
    return 0;
  }

  $log->warn('Warning! Execution subsystem unavailable. Queued tasks will not run!') unless $app->check_workers;

  $log->info('Internal scheduler process started.');

  # use Poll reactor to catch signals, or we have to call EV::Signal to install signals into EV
  Mojo::IOLoop->singleton->reactor(Mojo::Reactor::Poll->new);

  local $SIG{INT} = local $SIG{TERM} = sub { Mojo::IOLoop->stop };

  Mojo::IOLoop->next_tick(sub {
    for (@$tasks) {
      if ($_->{crontab}) {
        $self->_cron( $_ );
      } else {
        $log->info("Schedule ($_->{name}) not set -> skipped.");
      }
    }
  });

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  $log->info('Internal scheduler finished.');
}


sub _cron() {
  my ($self, $task) = @_;
  my $log = $self->app->log;
  carp "Bad $task->{name} crontab" unless $task->{crontab};

  my $cron = Algorithm::Cron->new(
    base => 'local',
    crontab => $task->{crontab},
  );
  $log->info("Schedule ($task->{name}: \"$task->{crontab}\") active.");

  my $time = time;
  # $cron, $time goes to closure
  my $fn;
  $fn = sub {
    $time = $cron->next_time($time);
    while ($time - time <= 0) {
      #say "Time diff negative!";
      $time = $cron->next_time($time);
    }
    Mojo::IOLoop->timer(($time - time) => sub {
      $log->info("EVENT from schedule ($task->{name}) started.");
      my $es;
      if ($task->{task}) {
        $log->warn('Warning! Execution subsystem unavailable.') unless $self->app->check_workers;
        my $id = $self->app->minion->enqueue(@{$task->{task}});
        $es = "enqueued task @{$task->{task}} $id";

      } elsif ($task->{cmd}) {
        my $e = eval { $self->app->commands->run(@{$task->{cmd}}, '--cron') };
        $es = (defined $e) ? "result: $e":"with error: $@";

      } else {
        $log->error("No action is defined for $task->{name}.");
        $es = 'with configuration error';
      }
      $log->info("EVENT from schedule ($task->{name}) finished $es.");
      $fn->();
    });
  };
  $fn->();
}

#-------------------------------------------------

1;
