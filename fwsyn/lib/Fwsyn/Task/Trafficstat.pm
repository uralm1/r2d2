package Fwsyn::Task::Trafficstat;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->ljq->add_task(traffic_stat => sub {
    my $job = shift;
    $job->app->rlog('Started traffic_stat task '.$job->id." pid $$");

    unless (eval { $job->app->traffic_stat }) {
      $job->app->rlog("Traffic statistics collection failed: $@");
      #$job->fail; # do not fail this job
      #return 1;
    }

    $job->app->rlog('Finished traffic_stat task '.$job->id);
    $job->finish;
  });
}


1;
