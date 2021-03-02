package Dhcpsyn::Task::Addreplaceclient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(addreplace_client => sub {
    my ($job, $v) = @_;
    croak 'Bad job parameter' unless $v;
    my $app = $job->app;
    $app->rlog('Started addreplace_client task '.$job->id." pid $$");

    my @err;
    my $r = eval { $app->dhcp_add_replace($v) };
    push @err, "Error adding/replacing client reservedip: $@" unless defined $r;

    if (@err) {
      $app->rlog(join(',', @err));
      $app->rlog('Failed addreplace_client task '.$job->id);
      $job->finish;
      return 1;
    }

    # send refreshed confirmation
    $r = eval {
      $app->ua->post(Mojo::URL->new('/refreshed')->to_abs($app->head_url)
        => json => { id => $v->{id}, subsys => $app->stash('subsys') })->result;
    };
    $app->log->error('Confirmation request failed, probably connection refused') unless defined $r;
    $app->log->error('Confirmation request error: '.substr($r->body, 0, 40)) if $r->is_error;

    $app->rlog('Finished addreplace_client task '.$job->id);
    $job->finish;
  });
}


1;
