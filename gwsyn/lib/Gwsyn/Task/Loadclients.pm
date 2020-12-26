package Gwsyn::Task::Loadclients;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(load_clients => sub {
    my $job = shift;
    $job->app->log->info("Start load_clients $$: ".$job->id);

    unless (eval { $job->app->load_clients }) {
      $job->app->log->error("Loading clients failed: $@");
      $job->fail;
      return 1;
    }

    $job->app->log->info("Finish load_clients $$: ".$job->id);
    $job->finish;
  });
}


1;
