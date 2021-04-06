package Fwsyn::Task::Addreplaceclient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Carp;

sub register {
  my ($self, $app) = @_;
  $app->ljq->add_task(addreplace_client => sub {
    my ($job, $v) = @_;
    croak 'Bad job parameter' unless $v;
    my $app = $job->app;
    $app->rlog('Started addreplace_client task '.$job->id." pid $$");

    my @err;
    # part 1: firewall rules directly
    my $r = eval { $app->fw_add_replace_rules($v) };
    push @err, "Error adding/replacing client rules in iptables: $@" unless defined $r;

    # part 1a: firewall file, no need to apply
    $r = eval { $app->fw_add_replace($v) };
    push @err, "Error adding/replacing client rules in firewall file: $@" unless defined $r;

    # part 2: tc
    if ($r = eval { $app->tc_add_replace($v) }) {
      push @err, "Error applying tc changes: $@" unless eval { $app->tc_apply };
    } elsif (!defined $r) {
      push @err, "Error adding/replacing client tc rules: $@";
    }

    if (@err) {
      $app->rlog(join(',', @err));
      $app->rlog('Failed addreplace_client task '.$job->id);
      $job->finish;
      return 1;
    }

    # send refreshed confirmation
    $r = eval {
      $app->ua->post(Mojo::URL->new('/refreshed')->to_abs($app->head_url)
        ->query(profile => $app->config('my_profiles'))
        => json => { id => $v->{id}, subsys => $app->stash('subsys') })->result;
    };
    unless (defined $r) {
      $app->log->error('Confirmation request failed, probably connection refused');
    } else {
      $app->log->error('Confirmation request error: '.substr($r->body, 0, 40)) if $r->is_error;
    }

    $app->rlog('Finished addreplace_client task '.$job->id);
    $job->finish;
  });
}


1;
