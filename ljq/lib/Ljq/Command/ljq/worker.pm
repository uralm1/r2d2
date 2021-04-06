package Ljq::Command::ljq::worker;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw(getopt);

has description => 'Start Worker';
has usage => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;

  my $worker = $self->app->ljq->worker;
  my $status = $worker->status;
  getopt \@args,
    'D|dequeue-timeout=i'    => \$status->{dequeue_timeout},
    'I|heartbeat-interval=i' => \$status->{heartbeat_interval},
    'R|repair-interval=i'    => \$status->{repair_interval};

  my $log = $self->app->log;
  $log->info("Worker $$ started");
  $worker->on(dequeue => sub { pop->once(spawn => \&_spawn) });
  $worker->run;
  $log->info("Worker $$ stopped");
}

sub _spawn {
  my ($job, $pid)  = @_;
  my ($id, $task) = ($job->id, $job->task);
  $job->app->log->debug(qq{Process $pid is performing job "$id" with task "$task"});
}

1;

=encoding utf8

=head1 NAME

Ljq::Command::ljq::worker - Ljq worker command

=head1 SYNOPSIS

  Usage: APPLICATION ljq worker [OPTIONS]

    ./myapp.pl ljq worker
    ./myapp.pl ljq worker -m production -I 15 -R 3600

  Options:
    -D, --dequeue-timeout <seconds>      Maximum amount of time to wait for
                                         jobs, defaults to 5
    -h, --help                           Show this summary of available options
        --home <path>                    Path to home directory of your
                                         application, defaults to the value of
                                         MOJO_HOME or auto-detection
    -I, --heartbeat-interval <seconds>   Heartbeat interval, defaults to 300
    -m, --mode <name>                    Operating mode for your application,
                                         defaults to the value of
                                         MOJO_MODE/PLACK_ENV or "development"
    -R, --repair-interval <seconds>      Repair interval, up to half of this
                                         value can be subtracted randomly to
                                         make sure not all workers repair at the
                                         same time, defaults to 21600 (6 hours)

=head1 DESCRIPTION

L<Ljq::Command::ljq::worker> starts a L<Ljq> worker. You can have as many workers as you like.

=head1 WORKER SIGNALS

The L<Ljq::Command::ljq::worker> process can be controlled at runtime with the following signals.

=head2 INT, TERM

Stop gracefully after finishing the current jobs.

=head2 QUIT

Stop immediately without finishing the current jobs.

=head1 JOB SIGNALS

The job processes spawned by the L<Ljq::Command::ljq::worker> process can be controlled at runtime with the
following signals.

=head2 INT, TERM

This signal starts out with the operating system default and allows for jobs to install a custom signal handler to stop
gracefully.

=head2 USR1, USR2

These signals start out being ignored and allow for jobs to install custom signal handlers.

=head1 ATTRIBUTES

L<Ljq::Command::ljq::worker> inherits all attributes from L<Mojolicious::Command> and implements the following
new ones.

=head2 description

  my $description = $worker->description;
  $worker         = $worker->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $worker->usage;
  $worker   = $worker->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Ljq::Command::ljq::worker> inherits all methods from L<Mojolicious::Command> and implements the following new
ones.

=head2 run

  $worker->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Minion>, L<Minion::Guide>, L<https://minion.pm>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
