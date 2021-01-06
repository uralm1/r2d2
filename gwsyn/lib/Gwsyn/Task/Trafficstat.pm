package Gwsyn::Task::Trafficstat;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(traffic_stat => sub {
    my $job = shift;
    $job->app->rlog("Start traffic_stat $$: ".$job->id);

    say "NOT IMPLEMENTED";
    #unless (eval { $job->app->load_clients }) {
    #  $job->app->rlog("Loading clients failed: $@");
    #  $job->fail;
    #  return 1;
    #}

    $job->app->rlog("Finish traffic_stat $$: ".$job->id);
    $job->finish;
  });
}


1;
