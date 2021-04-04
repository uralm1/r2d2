package Ljq::Worker;
use Mojo::Base 'Mojo::EventEmitter';

use Carp qw(croak);
use Mojo::Util qw(steady_time);

has [qw(status)] => sub { {} };
has [qw(id ljq)];

sub dequeue {
  my ($self, $wait, $options) = @_;

  # Worker not registered
  return undef unless my $id = $self->id;

  my $ljq = $self->ljq;
  return undef unless my $job = $ljq->_dequeue($id, $wait, $options);
  $job = Ljq::Job->new(args => $job->{args}, id => $job->{id}, ljq => $ljq, retries => $job->{retries}, task => $job->{task});
  $self->emit(dequeue => $job);
  return $job;
}

sub info { $_[0]->ljq->_worker_info($_[0]->id) }

sub new {
  my $self = shift->SUPER::new(@_);
  $self->on(busy => sub { sleep 1 });
  return $self;
}

sub register {
  my $self = shift;
  my $status = {status => $self->status};
  return $self->id($self->ljq->_register_worker($self->id, $status));
}

sub unregister {
  my $self = shift;
  $self->ljq->_unregister_worker(delete $self->{id});
  return $self;
}

sub run {
  my $self = shift;

  my $status = $self->status;
  $status->{dequeue_timeout} //= 2;
  $status->{heartbeat_interval} //= 300;
  $status->{performed} //= 0;
  $status->{repair_interval} //= 21600;

  # Reset event loop
  Mojo::IOLoop->reset;
  local $SIG{CHLD} = sub { };
  local $SIG{INT} = local $SIG{TERM} = sub { $self->{finished}++ };
  local $SIG{QUIT} = sub {
    ++$self->{finished} and kill 'KILL', map { $_->pid } @{$self->{jobs}};
  };

  eval { $self->_work until $self->{finished} && !@{$self->{jobs}} };
  my $err = $@;
  $self->unregister;
  croak $err if $err;
}

sub _work {
  my $self = shift;

  # Send heartbeats in regular intervals
  my $status = $self->status;
  $self->{last_heartbeat} ||= -$status->{heartbeat_interval};
  $self->register and $self->{last_heartbeat} = steady_time
    if ($self->{last_heartbeat} + $status->{heartbeat_interval}) < steady_time;

  # Repair in regular intervals
  $self->{last_repair} ||= 0;
  if (($self->{last_repair} + $status->{repair_interval}) < steady_time) {
    $self->ljq->repair;
    $self->{last_repair} = steady_time;
  }

  # Check if jobs are finished
  my $jobs = $self->{jobs} ||= [];
  @$jobs = map { $_->is_finished && ++$status->{performed} ? () : $_ } @$jobs;

  # Job limit has been reached or worker is stopping
  if ($self->{finished} || @$jobs >= 1) { return $self->emit('busy') }

  # Try to get more jobs
  my $max = $status->{dequeue_timeout};
  my $job = $self->emit('wait')->dequeue($max);
  push @$jobs, $job->start if $job;
}

1;
