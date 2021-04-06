package Fwsyn::Task::Blockclient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Carp;

sub register {
  my ($self, $app) = @_;
  $app->ljq->add_task(block_client => sub {
    my ($job, $id, $qs) = @_;
    croak 'Bad job parameters' unless ($id && defined $qs);
    my $app = $job->app;
    $app->rlog('Started block_client task '.$job->id." pid $$");

    my @err;
    # part 1: firewall rules directly
    my $r = eval { $app->fw_block_rules($id, $qs) };
    push @err, "Error blocking/unblocking client rules in iptables: $@" unless defined $r;

    # part 1a: firewall file, no need to apply
    $r = eval { $app->fw_block($id, $qs) };
    push @err, "Error blocking/unblocking client rules in firewall file: $@" unless defined $r;

    if (@err) {
      $app->rlog(join(',', @err));
      $app->rlog('Failed block_client task '.$job->id);
      $job->finish;
      return 1;
    }

    # send blocked confirmation
    $r = eval {
      $app->ua->post(Mojo::URL->new('/blocked')->to_abs($app->head_url)
        ->query(profile => $app->config('my_profiles'))
        => json => { id => $id, qs => $qs, subsys => $app->stash('subsys') })->result;
    };
    unless (defined $r) {
      $app->log->error('Confirmation request failed, probably connection refused');
    } else {
      $app->log->error('Confirmation request error: '.substr($r->body, 0, 40)) if $r->is_error;
    }

    $app->rlog('Finished block_client task '.$job->id);
    $job->finish;
  });
}


1;
