package Head::Task::CheckDBDel;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;
use Head::Ural::CompatChk;
use Head::Ural::Profiles;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(check_db_del => sub {
    my $job = shift;
    my $app = $job->app;

    $app->log->info('Check database for deletions started');

    unless (defined eval { _do($app) }) {
      chomp $@;
      $app->log->error("Fatal error. $@");
    } else {
      ###
      $app->dblog->info('Check database for deletions performed.', sync=>1);
    }

    $app->log->info('Check database for deletions finished');
    $job->finish;
  });
}


# _do($app)
# dies on error
sub _do {
  my $app = shift;

  my $profiles = $app->profiles;

  my $dcc = $app->del_compat_check;
  return 1 unless $dcc;
  #$dcc->dump;

  $dcc->eachdel(sub {
    my ($id, $prof) = @_;
    #say "$id => $prof has been removed!";
    # loop by agents
    my $e = eval { $profiles->exist($prof) };
    if (!defined $e) {
      $app->log->error("Refresh failed: database error (exist)!");
    } elsif (!$e) {
      $app->log->error("Refresh deleted device id $id failed: invalid profile!");
    } else {
      my $res = eval { $profiles->eachagent($prof, sub {
        my ($profile_key, $agent_key, $agent) = @_;

        my $agent_url = $agent->{url};

        eval { Head::Command::refresh::refresh_id($app, $agent_url, $id) };
        if ($@) {
          chomp $@;
          $app->log->error($@);
          $app->dblog->error($@, sync=>1);
        }
      }) };
      $app->log->error("Refresh failed, database error (eachagent)!") unless $res;
    }

  })->update();

  return 1;
}


1;
