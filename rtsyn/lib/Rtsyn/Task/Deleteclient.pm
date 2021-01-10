package Rtsyn::Task::Deleteclient;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(delete_client => sub {
    my ($job, $id) = @_;
    croak 'Bad job parameter' unless $id;
    my $app = $job->app;
    $app->rlog("Start delete_client $$: ".$job->id);

    my @err;
    my $r = eval { $app->rt_delete($id) };
    push @err, "Error deleting client rule: $@" unless defined $r;

    if (@err) {
      $app->rlog(join(',', @err));
      $job->fail;
      return 1;
    }

    $app->rlog("Finish delete_client $$: ".$job->id);
    $job->finish;
  });
}


1;
