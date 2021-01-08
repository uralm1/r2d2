package Gwsyn::Task::Deleteclient;
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
    # part 1: firewall
    if (my $r = eval { $app->fw_delete($id) }) {
      push @err, "Error applying firewall changes: $@" unless eval { $app->fw_apply };
    } elsif (!defined $r) {
      push @err, "Error deleting client firewall rules: $@";
    }

    # part 2: tc
    if (my $r = eval { $app->tc_delete($id) }) {
      push @err, "Error applying tc changes: $@" unless eval { $app->tc_apply };
    } elsif (!defined $r) {
      push @err, "Error deleting client tc rules: $@";
    }

    # part 3: dhcp
    if (my $r = eval { $app->dhcp_delete($id) }) {
      push @err, "Error applying dhcp changes: $@" unless eval { $app->dhcp_apply };
    } elsif (!defined $r) {
      push @err, "Error deleting client dhcp: $@";
    }

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
