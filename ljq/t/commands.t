use Mojo::Base -strict;

use Test::More;

subtest 'ljq' => sub {
  require Ljq::Command::ljq;
  my $ljq = Ljq::Command::ljq->new;
  ok $ljq->description, 'has a description';
  like $ljq->message,   qr/ljq/, 'has a message';
  like $ljq->hint,      qr/help/,   'has a hint';
};

subtest 'job' => sub {
  require Ljq::Command::ljq::job;
  my $job = Ljq::Command::ljq::job->new;
  ok $job->description, 'has a description';
  like $job->usage, qr/job/, 'has usage information';
};

subtest 'worker' => sub {
  require Ljq::Command::ljq::worker;
  my $worker = Ljq::Command::ljq::worker->new;
  ok $worker->description, 'has a description';
  like $worker->usage, qr/worker/, 'has usage information';
};

done_testing();
