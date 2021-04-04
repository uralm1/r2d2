use Mojo::Base -strict;

use Test::More;
use Storable ();

#use Mojo::File qw(curfile);
#use lib curfile->sibling('lib')->to_string;

use Ljq;
use Time::HiRes qw(usleep);
use Mojo::Promise;

my $test_db = 'test$$.dat';

# cleanup first
if (-f $test_db) {
  unlink $test_db, "$test_db.lock" or note 'Already clean';
}

my $ljq = Ljq->new($test_db);

subtest 'Nothing to repair' => sub {
  my $worker = $ljq->repair->worker;
  isa_ok $worker->ljq->app, 'Mojolicious', 'has default application';
};

subtest 'Register and unregister' => sub {
  my $worker = $ljq->worker;
  $worker->register;
  like $worker->info->{started}, qr/^[\d.]+$/, 'has timestamp';
  my $notified = $worker->info->{notified};
  like $notified, qr/^[\d.]+$/, 'has timestamp';
  my $id = $worker->id;
  is $worker->register->id, $id, 'same id';
  usleep 50000;
  ok $worker->register->info->{notified} > $notified, 'new timestamp';
  is $worker->unregister->info, undef, 'no information';
  is $worker->register->info->{pid}, $$, 'right pid';
  is $worker->unregister->info, undef, 'no information';
};

subtest 'Repair missing worker' => sub {
  $ljq->add_task(test => sub { });
  my $worker  = $ljq->worker->register;
  my $worker2 = $ljq->worker->register;
  isnt $worker2->id, $worker->id, 'new id';
  my $id = $ljq->enqueue('test');
  ok my $job = $worker2->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $worker2->info->{jobs}[0], $job->id, 'right id';
  $id = $worker2->id;
  undef $worker2;
  is $job->info->{state}, 'active', 'job is still active';
  ok !!$ljq->_worker_info($id), 'is registered';
  my $x = Storable::retrieve($test_db);
  my $w = $x->{workers}->{$id};
  $w->{notified} = time - ($ljq->missing_after + 1);
  Storable::store($x => $test_db);
  $ljq->repair;
  ok !$ljq->_worker_info($id), 'not registered';
  like $job->info->{finished}, qr/^[\d.]+$/,       'has finished timestamp';
  is $job->info->{state},      'failed',           'job is no longer active';
  is $job->info->{result},     'Worker went away', 'right result';
  $worker->unregister;
};

subtest 'Repair abandoned job' => sub {
  my $worker = $ljq->worker->register;
  my $id     = $ljq->enqueue('test');
  ok my $job = $worker->dequeue(1), 'job dequeued';
  is $job->id, $id, 'right id';
  $worker->unregister;
  $ljq->repair;
  is $job->info->{state},  'failed',           'job is no longer active';
  is $job->info->{result}, 'Worker went away', 'right result';
};

subtest 'Repair old jobs' => sub {
  is $ljq->remove_after, 172800, 'right default';
  my $worker = $ljq->worker->register;
  my $id     = $ljq->enqueue('test');
  my $id2    = $ljq->enqueue('test');
  my $id3    = $ljq->enqueue('test');
  $worker->dequeue(0)->perform for 1 .. 3;
  my $x = Storable::retrieve($test_db);
  my $j2 = $x->{jobs}->{$id2};
  $j2->{finished} -= $ljq->remove_after + 1;
  my $j3 = $x->{jobs}->{$id3};
  $j3->{finished} -= $ljq->remove_after + 1;
  Storable::store($x => $test_db);
  $worker->unregister;
  $ljq->repair;
  ok $ljq->job($id), 'job has not been cleaned up';
  ok !$ljq->job($id2), 'job has been cleaned up';
  ok !$ljq->job($id3), 'job has been cleaned up';
};

subtest 'List workers' => sub {
  my $worker  = $ljq->worker->register;
  my $worker2 = $ljq->worker->status({whatever => 'works!'})->register;
  my $batch = $ljq->_list_workers(0, 10);
  ok $batch->[0]{id},        'has id';
  is $batch->[0]{pid},       $$,    'right pid';
  like $batch->[0]{started}, qr/^[\d.]+$/, 'has timestamp';
  is $batch->[1]{pid},       $$,    'right pid';
  ok !$batch->[2], 'no more results';

  $batch = $ljq->_list_workers(0, 1);
  is $batch->[0]{id}, $worker2->id, 'right id';
  is_deeply $batch->[0]{status}, {whatever => 'works!'}, 'right status';
  ok !$batch->[1], 'no more results';
  $worker2->status({whatever => 'works too!'})->register;
  $batch = $ljq->_list_workers(0, 1);
  is_deeply $batch->[0]{status}, {whatever => 'works too!'}, 'right status';
  $batch = $ljq->_list_workers(1, 1);
  is $batch->[0]{id}, $worker->id, 'right id';
  ok !$batch->[1], 'no more results';
  $worker->unregister;
  $worker2->unregister;
};

subtest 'Reset' => sub {
  $ljq->worker->register;
  ok @{$ljq->_list_jobs(0, 1)},    'jobs';
  ok @{$ljq->_list_workers(0, 1)}, 'workers';
  $ljq->reset->repair;
  ok !@{$ljq->_list_jobs(0, 1)},    'no jobs';
  ok !@{$ljq->_list_workers(0, 1)}, 'no workers';
};

subtest 'Stats' => sub {
  $ljq->add_task(
    add => sub {
      my ($job, $first, $second) = @_;
      $job->finish({added => $first + $second});
    }
  );
  $ljq->add_task(fail => sub { die "Intentional failure!\n" });
  my $stats = $ljq->stats;
  is $stats->{active_workers},   0, 'no active workers';
  is $stats->{inactive_workers}, 0, 'no inactive workers';
  is $stats->{enqueued_jobs},    0, 'no enqueued jobs';
  is $stats->{active_jobs},      0, 'no active jobs';
  is $stats->{failed_jobs},      0, 'no failed jobs';
  is $stats->{finished_jobs},    0, 'no finished jobs';
  is $stats->{inactive_jobs},    0, 'no inactive jobs';
  is $stats->{delayed_jobs},     0, 'no delayed jobs';
  is $stats->{active_locks},     0, 'no active locks';
  my $worker = $ljq->worker->register;
  is $ljq->stats->{inactive_workers}, 1, 'one inactive worker';
  $ljq->enqueue('fail');
  is $ljq->stats->{enqueued_jobs}, 1, 'one enqueued job';
  $ljq->enqueue('fail');
  is $ljq->stats->{enqueued_jobs}, 2, 'two enqueued jobs';
  is $ljq->stats->{inactive_jobs}, 2, 'two inactive jobs';
  ok my $job = $worker->dequeue(0), 'job dequeued';
  $stats = $ljq->stats;
  is $stats->{active_workers}, 1, 'one active worker';
  is $stats->{active_jobs},    1, 'one active job';
  is $stats->{inactive_jobs},  1, 'one inactive job';
  $ljq->enqueue('fail');
  ok my $job2 = $worker->dequeue(0), 'job dequeued';
  $stats = $ljq->stats;
  is $stats->{active_workers}, 1, 'one active worker';
  is $stats->{active_jobs},    2, 'two active jobs';
  is $stats->{inactive_jobs},  1, 'one inactive job';
  ok $job2->finish, 'job finished';
  ok $job->finish,  'job finished';
  is $ljq->stats->{finished_jobs}, 2, 'two finished jobs';
  ok $job = $worker->dequeue(0), 'job dequeued';
  ok $job->fail, 'job failed';
  is $ljq->stats->{failed_jobs}, 1, 'one failed job';
  ok $job->retry, 'job retried';
  is $ljq->stats->{failed_jobs}, 0, 'no failed jobs';
  ok $worker->dequeue(0)->finish(['works']), 'job finished';
  $worker->unregister;
  $stats = $ljq->stats;
  is $stats->{active_workers},   0, 'no active workers';
  is $stats->{inactive_workers}, 0, 'no inactive workers';
  is $stats->{active_jobs},      0, 'no active jobs';
  is $stats->{failed_jobs},      0, 'no failed jobs';
  is $stats->{finished_jobs},    3, 'three finished jobs';
  is $stats->{inactive_jobs},    0, 'no inactive jobs';
  is $stats->{delayed_jobs},     0, 'no delayed jobs';
};

subtest 'List jobs' => sub {
  my $id = $ljq->enqueue('add');
  my $batch = $ljq->_list_jobs(0, 10);
  ok $batch->[0]{id},          'has id';
  is $batch->[0]{task},        'add',        'right task';
  is $batch->[0]{state},       'inactive',   'right state';
  is $batch->[0]{retries},     0,            'job has not been retried';
  like $batch->[0]{created},   qr/^[\d.]+$/, 'has created timestamp';
  is $batch->[1]{task},        'fail',       'right task';
  is_deeply $batch->[1]{args}, [], 'right arguments';
  is_deeply $batch->[1]{notes}, {}, 'right metadata';
  is_deeply $batch->[1]{result},   ['works'], 'right result';
  is $batch->[1]{state},           'finished', 'right state';
  is $batch->[1]{priority},        0,          'right priority';
  is $batch->[1]{retries},         1,            'job has been retried';
  like $batch->[1]{created},       qr/^[\d.]+$/, 'has created timestamp';
  like $batch->[1]{delayed},       qr/^[\d.]+$/, 'has delayed timestamp';
  like $batch->[1]{finished},      qr/^[\d.]+$/, 'has finished timestamp';
  like $batch->[1]{retried},       qr/^[\d.]+$/, 'has retried timestamp';
  like $batch->[1]{started},       qr/^[\d.]+$/, 'has started timestamp';
  is $batch->[2]{task},            'fail',       'right task';
  is $batch->[2]{state},           'finished',   'right state';
  is $batch->[2]{retries},         0,            'job has not been retried';
  is $batch->[3]{task},            'fail',       'right task';
  is $batch->[3]{state},           'finished',   'right state';
  is $batch->[3]{retries},         0,            'job has not been retried';
  ok !$batch->[4], 'no more results';

  $batch = $ljq->_list_jobs(0, 10, {state => 'inactive'});
  is $batch->[0]{state},   'inactive', 'right state';
  is $batch->[0]{retries}, 0,          'job has not been retried';
  ok !$batch->[1], 'no more results';

  $batch = $ljq->_list_jobs(0, 10, {task => 'add'});
  is $batch->[0]{task},    'add', 'right task';
  is $batch->[0]{retries}, 0,     'job has not been retried';
  ok !$batch->[1], 'no more results';

  $batch = $ljq->_list_jobs(0, 10, {task => 'fail'});
  is $batch->[0]{task}, 'fail', 'right task';
  is $batch->[1]{task}, 'fail', 'right task';
  is $batch->[2]{task}, 'fail', 'right task';
  ok !$batch->[3], 'no more results';

  my $id2 = $ljq->enqueue('test' => [] => {notes => {is_test => 1}});
  #$batch = $ljq->_list_jobs(0, 10, {notes => ['is_test']});
  #is $batch->[0]{task}, 'test', 'right task';
  #ok !$batch->[4], 'no more results';
  ok $ljq->job($id2)->remove, 'job removed';

  $batch = $ljq->_list_jobs(0, 1);
  is $batch->[0]{state},   'inactive', 'right state';
  is $batch->[0]{retries}, 0,          'job has not been retried';
  ok !$batch->[1], 'no more results';

  $batch = $ljq->_list_jobs(1, 1);
  is $batch->[0]{state},   'finished', 'right state';
  is $batch->[0]{retries}, 1,          'job has been retried';
  ok !$batch->[1], 'no more results';
  ok $ljq->job($id)->remove, 'job removed';
};

subtest 'Enqueue, dequeue and perform' => sub {
  is $ljq->job(12345), undef, 'job does not exist';
  my $id = $ljq->enqueue(add => [2, 2]);
  ok $ljq->job($id), 'job does exist';
  my $info = $ljq->job($id)->info;
  is_deeply $info->{args}, [2, 2], 'right arguments';
  is $info->{priority},    0,          'right priority';
  is $info->{state},       'inactive', 'right state';
  my $worker = $ljq->worker;
  is $worker->dequeue(0), undef, 'not registered';
  ok !$ljq->job($id)->info->{started}, 'no started timestamp';
  $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $worker->info->{jobs}[0], $job->id, 'right job';
  like $job->info->{created}, qr/^[\d.]+$/, 'has created timestamp';
  like $job->info->{started}, qr/^[\d.]+$/, 'has started timestamp';
  is_deeply $job->args, [2, 2], 'right arguments';
  is $job->info->{state}, 'active', 'right state';
  is $job->task,    'add', 'right task';
  is $job->retries, 0,     'job has not been retried';
  $id = $job->info->{worker};
  is $ljq->_worker_info($id)->{pid}, $$, 'right worker';
  ok !$job->info->{finished}, 'no finished timestamp';
  $job->perform;
  is $worker->info->{jobs}[0], undef, 'no jobs';
  like $job->info->{finished}, qr/^[\d.]+$/, 'has finished timestamp';
  is_deeply $job->info->{result}, {added => 4}, 'right result';
  is $job->info->{state}, 'finished', 'right state';
  $worker->unregister;
  $job = $ljq->job($job->id);
  is_deeply $job->args, [2, 2], 'right arguments';
  is $job->retries, 0, 'job has not been retried';
  is $job->info->{state}, 'finished', 'right state';
  is $job->task, 'add', 'right task';
};

subtest 'Retry and remove' => sub {
  my $id     = $ljq->enqueue(add => [5, 6]);
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->info->{attempts}, 1, 'job will be attempted once';
  is $job->info->{retries},  0, 'job has not been retried';
  is $job->id, $id, 'right id';
  ok $job->finish, 'job finished';
  ok !$worker->dequeue(0), 'no more jobs';
  $job = $ljq->job($id);
  ok !$job->info->{retried}, 'no retried timestamp';
  ok $job->retry, 'job retried';
  like $job->info->{retried}, qr/^[\d.]+$/, 'has retried timestamp';
  is $job->info->{state},     'inactive',   'right state';
  is $job->info->{retries},   1,            'job has been retried once';
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->retries, 1, 'job has been retried once';
  ok $job->retry,   'job retried';
  is $job->id,      $id, 'right id';
  is $job->info->{retries}, 2, 'job has been retried twice';
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->info->{state}, 'active', 'right state';
  ok $job->finish, 'job finished';
  ok $job->remove, 'job has been removed';
  ok !$job->retry, 'job not retried';
  is $job->info, undef, 'no information';
  $id  = $ljq->enqueue(add => [6, 5]);
  $job = $ljq->job($id);
  is $job->info->{state},   'inactive', 'right state';
  is $job->info->{retries}, 0,          'job has not been retried';
  ok $job->retry, 'job retried';
  is $job->info->{state},   'inactive', 'right state';
  is $job->info->{retries}, 1,          'job has been retried once';
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id,     $id, 'right id';
  ok $job->fail,   'job failed';
  ok $job->remove, 'job has been removed';
  is $job->info,   undef, 'no information';
  $id  = $ljq->enqueue(add => [5, 5]);
  $job = $ljq->job("$id");
  ok $job->remove, 'job has been removed';
  $worker->unregister;
};

subtest 'Jobs with priority' => sub {
  $ljq->enqueue(add => [1, 2]);
  my $id     = $ljq->enqueue(add => [2, 4], {priority => 1});
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->info->{priority}, 1, 'right priority';
  ok $job->finish, 'job finished';
  isnt $worker->dequeue(0)->id, $id, 'different id';
  $id = $ljq->enqueue(add => [2, 5]);
  ok $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->info->{priority}, 0, 'right priority';
  ok $job->finish, 'job finished';
  ok $job->retry({priority => 100}), 'job retried with higher priority';
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->info->{retries},  1,   'job has been retried once';
  is $job->info->{priority}, 100, 'high priority';
  ok $job->finish, 'job finished';
  ok $job->retry({priority => 0}), 'job retried with lower priority';
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->info->{retries},  2, 'job has been retried twice';
  is $job->info->{priority}, 0, 'low priority';
  ok $job->finish, 'job finished';
  $worker->unregister;
};

subtest 'Delayed jobs' => sub {
  my $id = $ljq->enqueue(add => [2, 1] => {delay => 100});
  is $ljq->stats->{delayed_jobs}, 1, 'one delayed job';
  my $worker = $ljq->worker->register;
  is $worker->dequeue(0), undef, 'too early for job';
  my $job = $ljq->job($id);
  ok $job->info->{delayed} > $job->info->{created}, 'delayed timestamp';

  my $x = Storable::retrieve($test_db);
  my $j = $x->{jobs}->{$id};
  $j->{delayed} = time - 3600*24;
  Storable::store($x => $test_db);

  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  like $job->info->{delayed}, qr/^[\d.]+$/, 'has delayed timestamp';
  ok $job->finish, 'job finished';
  ok $job->retry,  'job retried';
  my $info = $ljq->job($id)->info;
  ok $info->{delayed} <= $info->{retried}, 'no delayed timestamp';
  ok $job->remove, 'job removed';
  ok !$job->retry, 'job not retried';
  $id = $ljq->enqueue(add => [6, 9]);
  ok $job = $worker->dequeue(0), 'job dequeued';
  $info = $ljq->job($id)->info;

  ok int($info->{delayed}) <= int($info->{created}), 'no delayed timestamp';

  ok $job->fail, 'job failed';
  ok $job->retry({delay => 100}), 'job retried with delay';
  $info = $ljq->job($id)->info;
  is $info->{retries}, 1, 'job has been retried once';
  ok $info->{delayed} > $info->{retried}, 'delayed timestamp';
  ok $ljq->job($id)->remove, 'job has been removed';
  $worker->unregister;
};

subtest 'Events' => sub {
  my ($enqueue, $pid_start, $pid_stop);
  my ($failed, $finished) = (0, 0);
  $ljq->once(enqueue => sub { $enqueue = pop });
  $ljq->once(
    worker => sub {
      my ($ljq, $worker) = @_;
      $worker->on(
        dequeue => sub {
          my ($worker, $job) = @_;
          $job->on(failed   => sub { $failed++ });
          $job->on(finished => sub { $finished++ });
          $job->on(spawn    => sub { $pid_start = pop });
          $job->on(reap     => sub { $pid_stop  = pop });
          $job->on(
            start => sub {
              my $job = shift;
              return unless $job->task eq 'switcheroo';
              $job->task('add')->args->[-1] += 1;
            }
          );
          $job->on(
            finish => sub {
              my $job = shift;
              return unless defined(my $old = $job->info->{notes}{finish_count});
              $job->note(finish_count => $old + 1, finish_pid => $$);
            }
          );
          $job->on(
            cleanup => sub {
              my $job = shift;
              return unless defined(my $old = $job->info->{notes}{finish_count});
              $job->note(cleanup_count => $old + 1, cleanup_pid => $$);
            }
          );
        }
      );
    }
  );
  my $worker = $ljq->worker->register;
  my $id     = $ljq->enqueue(add => [3, 3]);
  is $enqueue, $id, 'enqueue event has been emitted';
  $ljq->enqueue(add => [4, 3]);
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $failed,   0, 'failed event has not been emitted';
  is $finished, 0, 'finished event has not been emitted';
  my $result;
  $job->on(finished => sub { $result = pop });
  ok $job->finish('Everything is fine!'), 'job finished';
  $job->perform;
  is $result,      'Everything is fine!', 'right result';
  is $failed,      0,                     'failed event has not been emitted';
  is $finished,    1,                     'finished event has been emitted once';
  isnt $pid_start, $$,        'new process id';
  isnt $pid_stop,  $$,        'new process id';
  is $pid_start,   $pid_stop, 'same process id';
  ok $job = $worker->dequeue(0), 'job dequeued';
  my $err;
  $job->on(failed => sub { $err = pop });
  $job->fail("test\n");
  $job->fail;
  is $err,      "test\n", 'right error';
  is $failed,   1,        'failed event has been emitted once';
  is $finished, 1,        'finished event has been emitted once';
  $ljq->add_task(switcheroo => sub { });
  $ljq->enqueue(switcheroo => [5, 3] => {notes => {finish_count => 0, before => 23}});
  ok $job = $worker->dequeue(0), 'job dequeued';
  $job->perform;
  is_deeply $job->info->{result}, {added => 9}, 'right result';
  is $job->info->{notes}{finish_count},  1, 'finish event has been emitted once';
  ok $job->info->{notes}{finish_pid},    'has a process id';
  isnt $job->info->{notes}{finish_pid},  $$, 'different process id';
  is $job->info->{notes}{before},        23, 'value still exists';
  is $job->info->{notes}{cleanup_count}, 2,  'cleanup event has been emitted once';
  ok $job->info->{notes}{cleanup_pid},   'has a process id';
  isnt $job->info->{notes}{cleanup_pid}, $$, 'different process id';
  $worker->unregister;
};

subtest 'Failed jobs' => sub {
  my $id     = $ljq->enqueue(add => [5, 6]);
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->info->{result}, undef, 'no result';
  ok $job->fail, 'job failed';
  ok !$job->finish, 'job not finished';
  is $job->info->{state},  'failed',        'right state';
  is $job->info->{result}, 'Unknown error', 'right result';
  $id = $ljq->enqueue(add => [6, 7]);
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  ok $job->fail('Something bad happened!'), 'job failed';
  is $job->info->{state},  'failed',                  'right state';
  is $job->info->{result}, 'Something bad happened!', 'right result';
  $id = $ljq->enqueue('fail');
  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  $job->perform;
  is $job->info->{state},  'failed',                 'right state';
  is $job->info->{result}, "Intentional failure!\n", 'right result';
  $worker->unregister;
};

subtest 'Nested data structures' => sub {
  $ljq->add_task(
    nested => sub {
      my ($job, $hash, $array) = @_;
      $job->note(bar => {baz => [1, 2, 3]});
      $job->note(baz => 'yada');
      $job->finish([{23 => $hash->{first}[0]{second} x $array->[0][0]}]);
    }
  );
  $ljq->enqueue('nested', [{first => [{second => 'test'}]}, [[3]]], {notes => {foo => [4, 5, 6]}});
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  $job->perform;
  is $job->info->{state}, 'finished', 'right state';
  ok $job->note(yada => ['works']), 'added metadata';
  ok !$ljq->_note(-1, {yada => ['failed']}), 'not added metadata';
  my $notes = {foo => [4, 5, 6], bar => {baz => [1, 2, 3]}, baz => 'yada', yada => ['works']};
  is_deeply $job->info->{notes}, $notes, 'right metadata';
  is_deeply $job->info->{result}, [{23 => 'testtesttest'}], 'right structure';
  ok $job->note(yada => undef, bar => undef), 'removed metadata';
  $notes = {foo => [4, 5, 6], baz => 'yada'};
  is_deeply $job->info->{notes}, $notes, 'right metadata';
  $worker->unregister;
};

subtest 'Perform job in a running event loop' => sub {
  my $id = $ljq->enqueue(add => [8, 9]);
  Mojo::Promise->new->resolve->then(sub { $ljq->perform_jobs })->wait;
  is $ljq->job($id)->info->{state}, 'finished', 'right state';
  is_deeply $ljq->job($id)->info->{result}, {added => 17}, 'right result';
};

subtest 'Job terminated unexpectedly' => sub {
  $ljq->add_task(exit => sub { exit 1 });
  my $id     = $ljq->enqueue('exit');
  my $worker = $ljq->worker->register;
  ok my $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  $job->perform;
  is $job->info->{state},  'failed',                                                'right state';
  is $job->info->{result}, 'Job terminated unexpectedly (exit code: 1, signal: 0)', 'right result';
  $worker->unregister;
};

subtest 'Multiple attempts while processing' => sub {
  is $ljq->backoff->(0),  15,     'right result';
  is $ljq->backoff->(1),  16,     'right result';
  is $ljq->backoff->(2),  31,     'right result';
  is $ljq->backoff->(3),  96,     'right result';
  is $ljq->backoff->(4),  271,    'right result';
  is $ljq->backoff->(5),  640,    'right result';
  is $ljq->backoff->(25), 390640, 'right result';

  my $id     = $ljq->enqueue(exit => [] => {attempts => 3});
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->retries, 0, 'job has not been retried';
  my $info = $job->info;
  is $info->{attempts}, 3,        'three attempts';
  is $info->{state},    'active', 'right state';
  $job->perform;
  $info = $job->info;
  is $info->{attempts}, 2,                                                       'two attempts';
  is $info->{state},    'inactive',                                              'right state';
  is $info->{result},   'Job terminated unexpectedly (exit code: 1, signal: 0)', 'right result';
  ok $info->{retried} < $job->info->{delayed}, 'delayed timestamp';

  my $x = Storable::retrieve($test_db);
  my $j = $x->{jobs}->{$id};
  $j->{delayed} = time;
  Storable::store($x => $test_db);

  ok $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->retries, 1, 'job has been retried';
  $info = $job->info;
  is $info->{attempts}, 2,        'two attempts';
  is $info->{state},    'active', 'right state';
  $job->perform;
  $info = $job->info;
  is $info->{attempts}, 1,          'one attempt';
  is $info->{state},    'inactive', 'right state';

  my $x = Storable::retrieve($test_db);
  my $j = $x->{jobs}->{$id};
  $j->{delayed} = time;
  Storable::store($x => $test_db);

  ok $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->retries, 2, 'two retries';
  $info = $job->info;
  is $info->{attempts}, 1,        'one attempt';
  is $info->{state},    'active', 'right state';
  $job->perform;
  $info = $job->info;
  is $info->{attempts}, 1,                                                       'one attempt';
  is $info->{state},    'failed',                                                'right state';
  is $info->{result},   'Job terminated unexpectedly (exit code: 1, signal: 0)', 'right result';

  ok $job->retry({attempts => 2}), 'job retried';
  ok $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  $job->perform;
  is $job->info->{state}, 'inactive', 'right state';

  my $x = Storable::retrieve($test_db);
  my $j = $x->{jobs}->{$id};
  $j->{delayed} = time;
  Storable::store($x => $test_db);

  ok $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  $job->perform;
  is $job->info->{state}, 'failed', 'right state';
  $worker->unregister;
};

subtest 'Multiple attempts during maintenance' => sub {
  my $id     = $ljq->enqueue(exit => [] => {attempts => 2});
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->retries, 0, 'job has not been retried';
  is $job->info->{attempts}, 2,        'job will be attempted twice';
  is $job->info->{state},    'active', 'right state';
  $worker->unregister;
  $ljq->repair;
  is $job->info->{state},  'inactive',         'right state';
  is $job->info->{result}, 'Worker went away', 'right result';
  ok $job->info->{retried} < $job->info->{delayed}, 'delayed timestamp';

  my $x = Storable::retrieve($test_db);
  my $j = $x->{jobs}->{$id};
  $j->{delayed} = time;
  Storable::store($x => $test_db);

  ok $job = $worker->register->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  is $job->retries, 1, 'job has been retried once';
  $worker->unregister;
  $ljq->repair;
  is $job->info->{state},  'failed',           'right state';
  is $job->info->{result}, 'Worker went away', 'right result';
};

subtest 'A job needs to be dequeued again after a retry' => sub {
  $ljq->add_task(restart => sub { });
  my $id     = $ljq->enqueue('restart');
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  is $job->id, $id, 'right id';
  ok $job->finish, 'job finished';
  is $job->info->{state}, 'finished', 'right state';
  ok $job->retry, 'job retried';
  is $job->info->{state}, 'inactive', 'right state';
  ok my $job2 = $worker->dequeue(0), 'job dequeued';
  is $job->info->{state}, 'active', 'right state';
  ok !$job->finish, 'job not finished';
  is $job->info->{state}, 'active', 'right state';
  is $job2->id, $id, 'right id';
  ok $job2->finish, 'job finished';
  ok !$job->retry, 'job not retried';
  is $job->info->{state}, 'finished', 'right state';
  $worker->unregister;
};

subtest 'Perform jobs concurrently' => sub {
  my $id     = $ljq->enqueue(add => [10, 11]);
  my $id2    = $ljq->enqueue(add => [12, 13]);
  my $id3    = $ljq->enqueue('test');
  my $id4    = $ljq->enqueue('exit');
  my $worker = $ljq->worker->register;
  ok my $job  = $worker->dequeue(0), 'job dequeued';
  ok my $job2 = $worker->dequeue(0), 'job dequeued';
  ok my $job3 = $worker->dequeue(0), 'job dequeued';
  ok my $job4 = $worker->dequeue(0), 'job dequeued';
  $job->start;
  $job2->start;
  $job3->start;
  $job4->start;
  my ($first, $second, $third, $fourth);
  usleep 50000
    until $first ||= $job->is_finished
    and $second  ||= $job2->is_finished
    and $third   ||= $job3->is_finished
    and $fourth  ||= $job4->is_finished;
  is $ljq->job($id)->info->{state}, 'finished', 'right state';
  is_deeply $ljq->job($id)->info->{result}, {added => 21}, 'right result';
  is $ljq->job($id2)->info->{state}, 'finished', 'right state';
  is_deeply $ljq->job($id2)->info->{result}, {added => 25}, 'right result';
  is $ljq->job($id3)->info->{state},  'finished',                                              'right state';
  is $ljq->job($id3)->info->{result}, undef,                                                   'no result';
  is $ljq->job($id4)->info->{state},  'failed',                                                'right state';
  is $ljq->job($id4)->info->{result}, 'Job terminated unexpectedly (exit code: 1, signal: 0)', 'right result';
  $worker->unregister;
};

subtest 'Stopping jobs' => sub {
  $ljq->add_task(
    long_running => sub {
      shift->note(started => 1);
      sleep 1000;
    }
  );
  my $worker = $ljq->worker->register;
  $ljq->enqueue('long_running');
  ok my $job = $worker->dequeue(0), 'job dequeued';
  ok $job->start->pid, 'has a process id';
  ok !$job->is_finished, 'job is not finished';
  $job->stop;
  usleep 5000 until $job->is_finished;
  is $job->info->{state},    'failed',                        'right state';
  like $job->info->{result}, qr/Job terminated unexpectedly/, 'right result';
  $ljq->enqueue('long_running');
  ok $job = $worker->dequeue(0), 'job dequeued';
  ok $job->start->pid, 'has a process id';
  ok !$job->is_finished, 'job is not finished';
  usleep 5000 until $job->info->{notes}{started};
  $job->kill('USR1');
  $job->kill('USR2');
  is $job->info->{state}, 'active', 'right state';
  $job->kill('INT');
  usleep 5000 until $job->is_finished;
  is $job->info->{state},    'failed',                        'right state';
  like $job->info->{result}, qr/Job terminated unexpectedly/, 'right result';
  $worker->unregister;
};

subtest 'Foreground' => sub {
  my $id  = $ljq->enqueue(test => [] => {attempts => 2});
  my $id2 = $ljq->enqueue('test');
  my $info = $ljq->job($id)->info;
  is $info->{attempts}, 2,          'job will be attempted twice';
  is $info->{state},    'inactive', 'right state';
  ok $ljq->foreground($id), 'performed first job';
  $info = $ljq->job($id)->info;
  is $info->{attempts}, 1,                   'job will be attempted once';
  is $info->{retries},  1,                   'job has been retried';
  is $info->{state},    'finished',          'right state';
  ok $ljq->foreground($id2), 'performed second job';
  $info = $ljq->job($id2)->info;
  is $info->{retries}, 1,                   'job has been retried';
  is $info->{state},   'finished',          'right state';
  $id = $ljq->enqueue('fail');
  eval { $ljq->foreground($id) };
  like $@, qr/Intentional failure!/, 'right error';
  $info = $ljq->job($id)->info;
  ok $info->{worker}, 'has worker';
  ok !$ljq->_worker_info($info->{worker}), 'not registered';
  is $info->{retries}, 1,                        'job has been retried';
  is $info->{state},   'failed',                 'right state';
  is $info->{result},  "Intentional failure!\n", 'right result';
};

subtest 'Single process worker' => sub {
  my $worker = $ljq->repair->worker->register;
  $ljq->add_task(
    good_job => sub {
      my ($job, $message) = @_;
      $job->finish("$message Mojo!");
    }
  );
  $ljq->add_task(
    bad_job => sub {
      my ($job, $message) = @_;
      die 'Bad job!';
    }
  );
  my $id  = $ljq->enqueue('good_job', ['Hello']);
  my $id2 = $ljq->enqueue('bad_job',  ['Hello']);
  while (my $job = $worker->dequeue(0)) {
    next unless my $err = $job->execute;
    $job->fail("Error: $err");
  }
  $worker->unregister;
  my $job = $ljq->job($id);
  is $job->info->{state},  'finished',    'right state';
  is $job->info->{result}, 'Hello Mojo!', 'right result';
  my $job2 = $ljq->job($id2);
  is $job2->info->{state},    'failed',            'right state';
  like $job2->info->{result}, qr/Error: Bad job!/, 'right error';
};

done_testing();
