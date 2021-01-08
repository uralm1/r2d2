package Gwsyn::Task::Addreplaceclient;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(addreplace_client => sub {
    my ($job, $v) = @_;
    croak 'Bad job parameter' unless $v;
    my $app = $job->app;
    $app->rlog("Start addreplace_client $$: ".$job->id);

    my @err;
    # part 1: firewall
    if (my $r = eval { $app->fw_add_replace($v) }) {
      push @err, "Error applying firewall changes: $@" unless eval { $app->fw_apply };
    } elsif (!defined $r) {
      push @err, "Error adding/replacing client firewall rules: $@";
    }

    # part 2: tc
    if (my $r = eval { $app->tc_add_replace($v) }) {
      push @err, "Error applying tc changes: $@" unless eval { $app->tc_apply };
    } elsif (!defined $r) {
      push @err, "Error adding/replacing client tc rules: $@";
    }

    # part 3: dhcp
    if (my $r = eval { $app->dhcp_add_replace($v) }) {
      push @err, "Error applying dhcp changes: $@" unless eval { $app->dhcp_apply };
    } elsif (!defined $r) {
      push @err, "Error adding/replacing client dhcp: $@";
    }

    if (@err) {
      $app->rlog(join(',', @err));
      $job->fail;
      return 1;
    }

    $app->rlog("Finish addreplace_client $$: ".$job->id);
    $job->finish;
  });
}


1;
