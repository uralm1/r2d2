package Mojolicious::Plugin::Ljq;
use Mojo::Base 'Mojolicious::Plugin';

use Ljq;

sub register {
  my ($self, $app, $conf) = @_;
  push @{$app->commands->namespaces}, 'Ljq::Command';
  my $ljq = Ljq->new($conf->{db})->app($app);
  $app->helper(ljq => sub {$ljq});
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Ljq - Lightweight job queue plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin(Ljq => {db => 'test.dat'});

  # Mojolicious::Lite
  plugin Ljq => {db => 'test.dat'};

  # Add tasks to your application
  app->ljq->add_task(slow_log => sub ($job, $msg) {
    sleep 5;
    $job->app->log->debug(qq{Received message "$msg"});
  });

  # Start jobs from anywhere in your application
  $c->ljq->enqueue(slow_log => ['test 123']);

  # Perform jobs in your tests
  $t->get_ok('/start_slow_log_job')->status_is(200);
  $t->get_ok('/start_another_job')->status_is(200);
  $t->app->ljq->perform_jobs;

=head1 DESCRIPTION

L<Mojolicious::Plugin::Ljq> is a L<Mojolicious> plugin for the L<Lightweight> job queue.

=head1 HELPERS

L<Mojolicious::Plugin::Ljq> implements the following helpers.

=head2 ljq

  my $ljq = $app->ljq;
  my $ljq = $c->ljq;

Get L<Ljq> object for application.

  # Add job to the queue
  $c->ljq->enqueue(foo => ['bar', 'baz']);

  # Perform jobs for testing
  $app->ljq->perform_jobs;

=head1 METHODS

L<Mojolicious::Plugin::Ljq> inherits all methods from L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new, 'test.dat');

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Minion>, L<Minion::Guide>, L<https://minion.pm>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
