package Gwsyn::Task::Loadclients;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(load_clients => sub {
    my $job = shift;
    $job->app->rlog("Start load_clients $$: ".$job->id);

    unless (eval { $job->app->load_clients }) {
      $job->app->rlog("Loading clients failed: $@");
      $job->fail;
      return 1;
    }

    $job->app->rlog("Finish load_clients $$: ".$job->id);
    $job->finish;
  });
}


1;
