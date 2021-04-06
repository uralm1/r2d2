package Ljq;
use Mojo::Base 'Mojo::EventEmitter';

use Carp qw(croak);
use Ljq::Job;
use Ljq::Worker;
use Mojo::IOLoop;
use Mojo::Server;
use Time::HiRes qw(time usleep);
use Data::Dumper;

has app => sub { $_[0]{app_ref} = Mojo::Server->new->build_app('Mojo::HelloWorld') }, weak => 1;
has backoff => sub { \&_backoff };
has missing_after => 1800;
has [qw(remove_after)] => 172800;
has tasks => sub { {} };
has 'file';

our $VERSION = '1.0';

sub add_task {
  my ($self, $name, $task) = @_;

  $self->tasks->{$name} = $task;
  return $self;
}

sub _dequeue {
  my ($self, $id, $wait, $options) = @_;
  return ($self->_try($id, $options) or do {
    usleep $wait * 1_000_000;
    $self->_try($id, $options);
  });
}

sub enqueue {
  my ($self, $task, $args, $options) = (shift, shift, shift // [], shift // {});
  my $guard = $self->_guard->_write;

  my $id = $guard->_job_id;
  my $job = {
    args => $args,
    attempts => $options->{attempts} // 1,
    created => time,
    delayed => time + ($options->{delay} // 0),
    id => $id,
    notes => $options->{notes} // {},
    priority => $options->{priority} // 0,
    retries => 0,
    state => 'inactive',
    task => $task
  };
  $guard->_jobs->{$id} = $job;

  $self->emit(enqueue => $id);
  return $id;
}

sub foreground {
  my ($self, $id) = @_;

  return undef unless my $job = $self->job($id);
  return undef unless $job->retry({attempts => 1});

  # Reset event loop
  Mojo::IOLoop->reset;
  local $SIG{CHLD} = local $SIG{INT} = local $SIG{TERM} = local $SIG{QUIT} = 'DEFAULT';

  my $worker = $self->worker->register;
  $job = $worker->dequeue(0 => {id => $id});
  my $err;
  if ($job) { defined($err = $job->execute) ? $job->fail($err) : $job->finish }
  $worker->unregister;

  return defined $err ? die $err : !!$job;
}

sub job {
  my ($self, $id) = @_;

  return undef unless my $job = $self->_job_info($id);
  return Ljq::Job->new(args => $job->{args}, id => $job->{id}, ljq => $self, retries => $job->{retries}, task => $job->{task});
}

sub new {
  my $self = shift->SUPER::new;
  $self->{file} = shift;
  croak 'Filename is missing' unless $self->{file};
  return $self;
}

sub perform_jobs {
  my ($self, $options) = @_;
  my $worker = $self->worker;
  while (my $job = $worker->register->dequeue(0, $options)) { $job->perform }
  $worker->unregister;
}

sub repair {
  my $self = shift;

  # Workers without heartbeat
  my $guard = $self->_guard->_write;
  my $workers = $guard->_workers;
  my $jobs = $guard->_jobs;
  my $after = time - $self->missing_after;
  $_->{notified} < $after and delete $workers->{$_->{id}} for values %$workers;

  # Old jobs
  $after = time - $self->remove_after;
  for my $job (values %$jobs) {
    next unless $job->{state} eq 'finished' and $job->{finished} <= $after;
    delete $jobs->{$job->{id}};
  }

  # Jobs with missing worker (can be retried)
  my @abandoned = map [@$_{qw(id retries)}],
      grep +($_->{state} eq 'active' and not exists $workers->{$_->{worker}}),
      values %$jobs;
  undef $guard;
  $self->_fail_job(@$_, 'Worker went away') for @abandoned;

  return $self;
}

sub reset { $_[0]->_guard->_save({} => $_[0]{file}); return $_[0] }

sub stats {
  my $self = shift;

  my ($active, $delayed) = (0, 0);
  my (%seen, %states);
  my $guard = $self->_guard;
  for my $job (values %{$guard->_jobs}) {
    ++$states{$job->{state}};
    ++$active if $job->{state} eq 'active' and not $seen{$job->{worker}}++;
    ++$delayed if $job->{state} eq 'inactive'
        and time < $job->{delayed};
  }

  return {
    active_workers => $active,
    inactive_workers => keys(%{$guard->_workers}) - $active,
    active_jobs => $states{active} // 0,
    delayed_jobs => $delayed,
    enqueued_jobs => $guard->_job_count,
    failed_jobs => $states{failed} // 0,
    finished_jobs => $states{finished} // 0,
    inactive_jobs => $states{inactive} // 0,
    active_locks => 0
  };
}

sub worker {
  my $self = shift;

  my $worker = Ljq::Worker->new(ljq => $self);
  $self->emit(worker => $worker);
  return $worker;
}

sub _backoff { (shift()**4) + 15 }

sub _note {
  my ($self, $id, $merge) = @_;
  my $guard = $self->_guard;
  return undef unless my $job = $guard->_write->_jobs->{$id};
  while (my ($k, $v) = each %$merge) {
    if (defined $v) {
      $job->{notes}{$k} = $v;
    } else {
      delete $job->{notes}{$k};
    }
  }
  return 1;
}

sub _register_worker {
  my ($self, $id, $options) = (shift, shift, shift // {});
  my $guard = $self->_guard->_write;
  my $worker = $id ? $guard->_workers->{$id} : undef;
  unless ($worker) {
    $worker = {id => $guard->_id, pid => $$, started => time};
    $guard->_workers->{$worker->{id}} = $worker;
  }
  @$worker{qw(notified status)} = (time, $options->{status} // {});
  return $worker->{id};
}

sub _unregister_worker {
  my ($self, $id) = @_;
  my $guard = $self->_guard->_write;
  delete $guard->_workers->{$id};
}

sub _retry_job {
  my ($self, $id, $retries, $options) = (shift, shift, shift, shift // {});

  my $guard = $self->_guard;
  return undef
    unless my $job = $guard->_job($id, qw(active failed finished inactive));
  return undef unless $job->{retries} == $retries;
  $guard->_write;
  ++$job->{retries};
  $job->{delayed} = time + $options->{delay} if $options->{delay};
  exists $options->{$_} and $job->{$_} = $options->{$_} for qw(priority attempts);
  @$job{qw(retried state)} = (time, 'inactive');
  delete @$job{qw(finished started worker)};

  return 1;
}

sub _remove_job {
  my ($self, $id) = @_;
  my $guard = $self->_guard;
  delete $guard->_write->_jobs->{$id}
    if my $removed = !!$guard->_job($id, qw(failed finished inactive));
  return $removed;
}

sub _fail_job { shift->_update(1, @_) }

sub _finish_job { shift->_update(0, @_) }

sub _try {
  my ($self, $id, $options) = @_;
  my $tasks = $self->tasks;

  my $now = time;
  my $guard = $self->_guard;
  my $jobs = $guard->_jobs;
  my @ready = sort { $b->{priority} <=> $a->{priority}
        || $a->{created} <=> $b->{created} }
    grep +($_->{state} eq 'inactive' and $tasks->{$_->{task}} and $_->{delayed} <= $now),
    values %$jobs;

  my $job;
  CANDIDATE: for my $candidate (@ready) {
    $job = $candidate and last CANDIDATE
      if (!exists $options->{id} or $candidate->{id} eq $options->{id});
  }

  return undef unless $job;
  $guard->_write;
  @$job{qw(started state worker)} = (time, 'active', $id);
  return $job;
}

sub _update {
  my ($self, $fail, $id, $retries, $result) = @_;

  my $guard = $self->_guard;
  return undef unless my $job = $guard->_job($id, 'active');
  return undef unless $job->{retries} == $retries;

  $guard->_write;
  @$job{qw(finished result)} = (time, $result);
  $job->{state} = $fail ? 'failed' : 'finished';
  undef $guard;

  #return 1 unless $fail and $job->{attempts} > $retries + 1;
  my $attempts = $job->{attempts};
  return 1 unless $fail and $attempts > 1;
  my $delay = $self->backoff->($retries);
  return $self->_retry_job($id, $retries, {delay => $delay,
    attempts => $attempts > 1 ? $attempts - 1 : 1});
}

sub _job_info {
  my ($self, $id) = @_;
  my $guard = $self->_guard;
  return undef unless my $job = $guard->_jobs->{$id};
  return $job;
}

sub _worker_info { $_[0]->__worker_info($_[0]->_guard, $_[1]) }

sub __worker_info {
  my ($self, $guard, $id) = @_;

  return undef unless $id && (my $worker = $guard->_workers->{$id});
  my @jobs = map $_->{id},
      grep +($_->{state} eq 'active' and $_->{worker} eq $id),
      values %{$guard->_jobs};

  return {%$worker, jobs => \@jobs};
}

sub _list_jobs {
  my ($self, $offset, $limit, $options) = @_;
  my $guard = $self->_guard;
  my @jobs = sort { $b->{created} <=> $a->{created} }
  grep +( (not defined $options->{state} or $_->{state} eq $options->{state})
      and (not defined $options->{task} or $_->{task} eq $options->{task})
  ), values %{$guard->_jobs};

  return [grep defined, @jobs[$offset .. ($offset + $limit - 1)]];
}

sub _list_workers {
  my ($self, $offset, $limit) = @_;
  my $guard = $self->_guard;
  my @workers = map { $self->__worker_info($guard, $_->{id}) }
    sort { $b->{started} <=> $a->{started} } values %{$guard->_workers};
  return [grep {defined} @workers[$offset .. ($offset + $limit - 1)]];
}

sub _guard { Ljq::_Guard->new(ljq => shift) }


package Ljq::_Guard;
use Mojo::Base -base;

use Fcntl ':flock';
use Digest::MD5 'md5_hex';
use Storable ();

sub DESTROY {
  my $self = shift;
  $self->_save($self->_data => $self->{ljq}->file) if $self->{write};
  flock $self->{lock}, LOCK_UN;
}

sub new {
  my $self = shift->SUPER::new(@_);
  my $path = $self->{ljq}->file;
  $self->_save({} => $path) unless -f $path;
  open $self->{lock}, '>', "$path.lock";
  flock $self->{lock}, LOCK_EX;
  return $self;
}

sub _data { $_[0]{data} //= $_[0]->_load($_[0]{ljq}->file) }

sub _id {
  my $self = shift;
  my $id;
  do { $id = md5_hex(time . rand 999) } while $self->_workers->{$id};
  return $id;
}

sub _job {
  my ($self, $id) = (shift, shift);
  return undef unless my $job = $self->_jobs->{$id};
  return grep(($job->{state} eq $_), @_) ? $job : undef;
}

sub _job_count { $_[0]->_data->{job_count} //= 0 }

sub _job_id {
  my $self = shift;
  my $id;
  do { $id = md5_hex(time . rand 999) } while $self->_jobs->{$id};
  ++$self->_data->{job_count};
  return $id;
}

sub _jobs { $_[0]->_data->{jobs} //= {} }

sub _load { Storable::retrieve($_[1]) }

sub _save { Storable::store($_[1] => $_[2]) }

sub _workers { $_[0]->_data->{workers} //= {} }

sub _write { ++$_[0]{write} && return $_[0] }

1;
__END__
