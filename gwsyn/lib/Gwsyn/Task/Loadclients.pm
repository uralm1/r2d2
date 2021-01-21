package Gwsyn::Task::Loadclients;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(load_clients => sub {
    my $job = shift;
    $job->app->rlog('Started load_clients task '.$job->id." pid $$");

    unless (eval { $job->app->load_clients }) {
      $job->app->rlog("Loading clients task failed: $@");
      $job->fail;
      return 1;
    }

    $job->app->rlog('Finished load_clients task '.$job->id);
    $job->finish;
  });
}


1;
