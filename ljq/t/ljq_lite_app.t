use Mojo::Base -strict;

BEGIN { $ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll' }

use Test::More;

use Mojo::IOLoop;
use Mojo::Promise;
use Mojolicious::Lite;
use Test::Mojo;

my $test_db = 'test$$.dat';

# cleanup first
if (-f $test_db) {
  unlink $test_db, "$test_db.lock" or note 'Already clean';
}

plugin Ljq => {db => $test_db};

app->ljq->add_task(
  add => sub {
    my ($job, $first, $second) = @_;
    Mojo::IOLoop->next_tick(sub {
      $job->finish($first + $second);
      Mojo::IOLoop->stop;
    });
    Mojo::IOLoop->start;
  }
);

get '/add' => sub {
  my $c  = shift;
  my $id = $c->ljq->enqueue(add => [$c->param('first'), $c->param('second')] => {queue => 'test'});
  $c->render(text => $id);
};

get '/result' => sub {
  my $c = shift;
  $c->render(text => $c->ljq->job($c->param('id'))->info->{result});
};

my $t = Test::Mojo->new;

subtest 'Perform jobs automatically' => sub {
  $t->get_ok('/add' => form => {first => 1, second => 2})->status_is(200);
  $t->app->ljq->perform_jobs({queues => ['test']});
  $t->get_ok('/result' => form => {id    => $t->tx->res->text})->status_is(200)->content_is('3');
  $t->get_ok('/add'    => form => {first => 2, second => 3})->status_is(200);
  my $first = $t->tx->res->text;
  $t->get_ok('/add' => form => {first => 4, second => 5})->status_is(200);
  my $second = $t->tx->res->text;
  Mojo::Promise->new->resolve->then(sub { $t->app->ljq->perform_jobs({queues => ['test']}) })->wait;
  $t->get_ok('/result' => form => {id => $first})->status_is(200)->content_is('5');
  $t->get_ok('/result' => form => {id => $second})->status_is(200)->content_is('9');
};

done_testing();
