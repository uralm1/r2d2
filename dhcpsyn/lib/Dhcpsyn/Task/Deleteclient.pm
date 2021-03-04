package Dhcpsyn::Task::Deleteclient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(delete_client => sub {
    my ($job, $id) = @_;
    croak 'Bad job parameter' unless $id;
    my $app = $job->app;
    $app->rlog('Started delete_client task '.$job->id." pid $$");

    my @err;
    my $r = eval { $app->dhcp_delete($id) };
    push @err, "Error deleting client reservedip: $@" unless defined $r;

    if (@err) {
      $app->rlog(join(',', @err));
      $app->rlog('Failed delete_client task '.$job->id);
      $job->finish;
      return 1;
    }

    # send refreshed confirmation
    $r = eval {
      $app->ua->post(Mojo::URL->new('/refreshed')->to_abs($app->head_url)
        => json => { id => $id, subsys => $app->stash('subsys') })->result;
    };
    unless (defined $r) {
      $app->log->error('Confirmation request failed, probably connection refused');
    } else {
      $app->log->error('Confirmation request error: '.substr($r->body, 0, 40)) if $r->is_error;
    }

    $app->rlog('Finished delete_client task '.$job->id);
    $job->finish;
  });
}


1;
