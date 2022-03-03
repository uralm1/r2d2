package Head::Task::CheckDB;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;
use Head::Ural::SyncQueue;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(check_db => sub {
    my $job = shift;
    my $app = $job->app;

    unless (defined eval { _do($app) }) {
      chomp $@;
      $app->log->error("Fatal error. $@");
    } else {
      ###
      my $m = 'Check sync queue operation performed.';
      $app->log->info($m);
      #$app->dblog->info($m, sync => 1);
    }

    $job->finish;
  });
}


# _do($app)
# dies on error
sub _do {
  my $app = shift;

  $app->syncqueue->get_flags(sub {
    my ($id, $profile, $url) = @_;

    eval { Head::Command::refresh::refresh_id($app, $url, $id) };
    if ($@) {
      chomp $@;
      $app->log->error($@);
      $app->dblog->error($@, sync => 1);
    }
  });

  return 1;
}


1;
