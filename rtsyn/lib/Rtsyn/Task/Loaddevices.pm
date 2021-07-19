package Rtsyn::Task::Loaddevices;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
#use Carp;

sub register {
  my ($self, $app) = @_;
  $app->ljq->add_task(load_devices => sub {
    my $job = shift;
    $job->app->rlog('Started load_devices task '.$job->id." pid $$");

    unless (eval { $job->app->load_devices }) {
      chomp $@;
      $job->app->rlog("Loading devices task failed: $@");
      $job->fail;
      return 1;
    }

    # send reloaded confirmation
    my $r = eval {
      $app->ua->post(Mojo::URL->new('/reloaded')->to_abs($app->head_url)
        ->query(profile => $app->config('my_profiles'))
        => json => { subsys => $app->stash('subsys') })->result;
    };
    unless (defined $r) {
      $app->log->error('Confirmation request failed, probably connection refused');
    } else {
      $app->log->error('Confirmation request error: '.substr($r->body, 0, 40)) if $r->is_error;
    }

    $job->app->rlog('Finished load_devices task '.$job->id);
    $job->finish;
  });
}


1;
