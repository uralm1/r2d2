use Mojo::Base -strict;

use Test::More;
use Storable ();

#use Mojo::File qw(curfile);
#use lib curfile->sibling('lib')->to_string;

use Ljq;

my $test_db = 'test$$.dat';

subtest 'Execute task over empty db' => sub {
  # cleanup first
  if (-f $test_db) {
    unlink $test_db, "$test_db.lock" or note 'Already clean';
  }

  my $ljq = Ljq->new($test_db);
  $ljq->add_task(
    add => sub {
      my ($job, $first, $second) = @_;
      $job->finish($first + $second);
    }
  );
  my $id = $ljq->enqueue(add => [2, 2]);
  ok $ljq->job($id), 'job does exist';
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  $job->execute;
  is $job->info->{result}, 4, 'job yields right result';
  is $job->info->{state}, 'finished', 'job finished';
  $worker->unregister;
  $ljq = undef;
};

subtest 'Execute task over broken db' => sub {
  # now try to break db
  truncate $test_db, 40 or die $!;

  my $ljq = Ljq->new($test_db);
  $ljq->add_task(
    add2 => sub {
      my ($job, $first, $second) = @_;
      $job->finish($first + $second);
    }
  );
  my $id = $ljq->enqueue(add2 => [2, 2]); # uses Storable here
  ok $ljq->job($id), 'job does exist';
  my $worker = $ljq->worker->register;
  ok my $job = $worker->dequeue(0), 'job dequeued';
  $job->execute;
  is $job->info->{result}, 4, 'job yields right result';
  is $job->info->{state}, 'finished', 'job finished';
  $worker->unregister;
};

done_testing();
