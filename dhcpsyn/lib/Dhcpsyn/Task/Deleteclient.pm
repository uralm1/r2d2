package Dhcpsyn::Task::Deleteclient;
use Mojo::Base 'Mojolicious::Plugin';

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
      $job->fail;
      return 1;
    }

    $app->rlog('Finished delete_client task '.$job->id);
    $job->finish;
  });
}


1;
