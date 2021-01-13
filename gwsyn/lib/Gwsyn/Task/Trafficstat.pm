package Gwsyn::Task::Trafficstat;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(traffic_stat => sub {
    my $job = shift;
    $job->app->rlog("Start traffic_stat $$: ".$job->id);

    unless (eval { $job->app->traffic_stat }) {
      $job->app->rlog("Traffic statistics collection failed: $@");
      #$job->fail; # do not fail this job
      #return 1;
    }

    $job->app->rlog("Finish traffic_stat $$: ".$job->id);
    $job->finish;
  });
}


1;
