package Ljq::Command::ljq::job;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Date;
use Mojo::JSON qw(decode_json);
use Mojo::Util qw(dumper getopt tablify);

has description => 'Manage Lightweight job queue jobs';
has usage => sub { shift->extract_usage };

sub run {
  my ($self, @args) = @_;

  my ($args, $options) = ([], {});
  getopt \@args,
    'A|attempts=i'  => \$options->{attempts},
    'a|args=s'      => sub { $args = decode_json($_[1]) },
    'd|delay=i'     => \$options->{delay},
    'e|enqueue=s'   => \my $enqueue,
    'l|limit=i'     => \(my $limit             = 100),
    'n|notes=s'     => sub { $options->{notes} = decode_json($_[1]) },
    'o|offset=i'    => \(my $offset            = 0),
    'p|priority=i'  => \$options->{priority},
    'R|retry'       => \my $retry,
    'remove'        => \my $remove,
    'S|state=s'     => sub { push @{$options->{states}}, $_[1] },
    's|stats'       => \my $stats,
    'T|tasks'       => \my $tasks,
    't|task=s'      => sub { push @{$options->{tasks}}, $_[1] },
    'w|workers'     => \my $workers;

  my $ljq = $self->app->ljq;

  # Enqueue
  return say $ljq->enqueue($enqueue, $args, $options) if $enqueue;

  # Show stats
  return $self->_stats if $stats;

  # List tasks
  return print tablify [keys %{$ljq->tasks}] if $tasks;

  # List jobs/workers
  my $id = @args ? shift @args : undef;
  return $id ? $self->_worker($id) : $self->_list_workers($offset, $limit) if $workers;
  return $self->_list_jobs($offset, $limit, $options) unless defined $id;
  die "Job does not exist.\n" unless my $job = $ljq->job($id);

  # Remove job
  return $job->remove || die "Job is active.\n" if $remove;

  # Retry job
  return $job->retry($options) || die "Job is active.\n" if $retry;

  # Job info
  print dumper _datetime($job->info);
}

sub _datetime {
  my $hash = shift;
  $hash->{$_} and $hash->{$_} = Mojo::Date->new($hash->{$_})->to_datetime
    for qw(created delayed finished notified retried started);
  return $hash;
}

sub _list_jobs {
  my $jobs = shift->app->ljq->_list_jobs(@_);
  print tablify [map { [@$_{qw(id state queue task)}] } @$jobs];
}

sub _list_workers {
  my $workers = shift->app->ljq->_list_workers(@_);
  my @workers = map { [$_->{id}, $_->{pid}] } @$workers;
  print tablify \@workers;
}

sub _stats { print dumper shift->app->ljq->stats }

sub _worker {
  my $worker = shift->app->ljq->_worker_info(@_);
  die "Worker does not exist.\n" unless $worker;
  print dumper _datetime($worker);
}

1;

=encoding utf8

=head1 NAME

Ljq::Command::ljq::job - Ljq job command

=head1 SYNOPSIS

  Usage: APPLICATION ljq job [OPTIONS] [IDS]

    ./myapp.pl ljq job
    ./myapp.pl ljq job 10023
    ./myapp.pl ljq job -w
    ./myapp.pl ljq job -w 23
    ./myapp.pl ljq job -s
    ./myapp.pl ljq job -f 10023
    ./myapp.pl ljq job -e foo -a '[23, "bar"]'
    ./myapp.pl ljq job -R -d 10 10023
    ./myapp.pl ljq job --remove 10023
    ./myapp.pl ljq job -n '["test"]'

  Options:
    -A, --attempts <number>     Number of times performing this new job will be
                                attempted, defaults to 1
    -a, --args <JSON array>     Arguments for new job or worker remote control
                                command in JSON format
    -d, --delay <seconds>       Delay new job for this many seconds
    -e, --enqueue <task>        New job to be enqueued
    -h, --help                  Show this summary of available options
        --home <path>           Path to home directory of your application,
                                defaults to the value of MOJO_HOME or
                                auto-detection
    -l, --limit <number>        Number of jobs/workers to show when listing
                                them, defaults to 100
    -m, --mode <name>           Operating mode for your application, defaults to
                                the value of MOJO_MODE/PLACK_ENV or
                                "development"
    -n, --notes <JSON>          Notes in JSON format for new job or list only
                                jobs with one of these notes
    -o, --offset <number>       Number of jobs/workers to skip when listing
                                them, defaults to 0
    -p, --priority <number>     Priority of new job, defaults to 0
    -R, --retry                 Retry job
        --remove                Remove job
    -S, --state <name>          List only jobs in these states
    -s, --stats                 Show queue statistics
    -T, --tasks                 List available tasks
    -t, --task <name>           List only jobs for these tasks
    -w, --workers               List workers instead of jobs, or show
                                information for a specific worker

=head1 DESCRIPTION

L<Ljq::Command::ljq::job> manages the L<Ljq> job queue.

=head1 ATTRIBUTES

L<Ljq::Command::ljq::job> inherits all attributes from L<Mojolicious::Command> and implements the following new
ones.

=head2 description

  my $description = $job->description;
  $job            = $job->description('Foo');

Short description of this command, used for the command list.

=head2 usage

  my $usage = $job->usage;
  $job      = $job->usage('Foo');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Ljq::Command::ljq::job> inherits all methods from L<Mojolicious::Command> and implements the following new
ones.

=head2 run

  $job->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Minion>, L<Minion::Guide>, L<https://ljq.pm>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
