package Rtsyn::Task::Addreplaceclient;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(addreplace_client => sub {
    my ($job, $v) = @_;
    croak 'Bad job parameter' unless $v;
    my $app = $job->app;
    $app->rlog('Started addreplace_client task '.$job->id." pid $$");

    my @err;
    my $r = eval { $app->rt_add_replace($v) };
    push @err, "Error adding/replacing client rule: $@" unless defined $r;

    if (@err) {
      $app->rlog(join(',', @err));
      $job->fail;
      return 1;
    }

    $app->rlog('Finished addreplace_client task '.$job->id);
    $job->finish;
  });
}


1;
