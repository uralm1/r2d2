package Ljq::Job;
use Mojo::Base 'Mojo::EventEmitter';

use Carp qw(croak);
use Mojo::IOLoop;
use POSIX qw(WNOHANG);

has [qw(args id ljq retries task)];

sub app { shift->ljq->app }

sub execute {
  my $self = shift;
  return eval {
    my $task = $self->ljq->tasks->{$self->emit('start')->task};
    $self->$task(@{$self->args});
    !!$self->emit('finish');
  } ? undef : $@;
}

sub fail {
  my ($self, $err) = (shift, shift // 'Unknown error');
  my $ok = $self->ljq->_fail_job($self->id, $self->retries, $err);
  return $ok ? !!$self->emit(failed => $err) : undef;
}

sub finish {
  my ($self, $result) = @_;
  my $ok = $self->ljq->_finish_job($self->id, $self->retries, $result);
  return $ok ? !!$self->emit(finished => $result) : undef;
}

sub info { $_[0]->ljq->_job_info($_[0]->id) }

sub is_finished {
  my $self = shift;
  return undef unless waitpid($self->{pid}, WNOHANG) == $self->{pid};
  $self->_reap($? ? (1, $? >> 8, $? & 127) : ());
  return 1;
}

sub kill { CORE::kill($_[1], $_[0]->{pid}) }

sub note {
  my $self = shift;
  return $self->ljq->_note($self->id, {@_});
}

sub perform {
  my $self = shift;
  waitpid $self->start->pid, 0;
  $self->_reap($? ? (1, $? >> 8, $? & 127) : ());
}

sub pid { shift->{pid} }

sub remove { $_[0]->ljq->_remove_job($_[0]->id) }

sub retry {
  my $self = shift;
  return $self->ljq->_retry_job($self->id, $self->retries, @_);
}

sub start {
  my $self = shift;

  # Parent
  die "Can't fork: $!" unless defined(my $pid = fork);
  return $self->emit(spawn => $pid) if $self->{pid} = $pid;

  # Reset event loop
  Mojo::IOLoop->reset;
  local $SIG{CHLD} = local $SIG{INT} = local $SIG{TERM} = local $SIG{QUIT} = 'DEFAULT';
  # doesnt emulated on windows
  local $SIG{USR1} = local $SIG{USR2} = 'IGNORE' unless $^O =~ /^mswin/i;

  # Child
  if (defined(my $err = $self->execute)) { $self->fail($err) }
  $self->emit('cleanup');
  if ($^O =~ /^mswin/i) { exit(0); } else
  { POSIX::_exit(0); }
}

sub stop { shift->kill('KILL') }

sub _reap {
  my ($self, $term, $exit, $sig) = @_;
  $self->emit(reap => $self->{pid});
  $term ? $self->fail("Job terminated unexpectedly (exit code: $exit, signal: $sig)") : $self->finish;
}

1;
