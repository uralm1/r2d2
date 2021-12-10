package Head::Task::Connectivity;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;
use Mojo::URL;
use Mojo::Promise;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(connectivity => sub {
    my $job = shift;
    my $app = $job->app;

    $app->log->info('Check connectivity operation started');

    unless (defined eval { _do($app) }) {
      chomp $@;
      $app->log->error("Fatal error. $@");
    } else {
      ###
      $app->dblog->info('Check connectivity operation performed.', sync=>1);
    }

    $app->log->info('Check connectivity operation finished');
    $job->finish;
  });
}


# _do($app)
# _do($app, 'profile_key')
# dies on error
sub _do {
  my ($app, $profile) = @_;

  my $profiles = $app->profiles->hash;
  if (defined $profile) {
    die "Requested profile configuration doesn't exist!\n" unless $profiles->{$profile};
  }

  # undefined $profile means - all profiles
  $app->profiles->eachagent($profile, sub {
    my ($profile_key, $agent_key, $agent) = @_;

    $app->log->info("Checking agent [profile: $profile_key, type: $agent->{type}, url: $agent->{url}]...");

    $app->ua->get_p(Mojo::URL->new("$agent->{url}/subsys") => {Accept => 'application/json'})
    ->then(sub {
      my $tx = shift;
      my $res = $tx->result;

      if (defined $res && $res->is_success && (my $v = $res->json)) {
        my $ok = 1;
        for (qw/subsys version profiles/) { $ok = undef unless $v->{$_} }
        $ok = undef if ref($v->{profiles}) ne 'ARRAY';
        if ($ok) {
          $app->log->info("OK: [subsys: $v->{subsys}, version: $v->{version}, profiles: ".join(',', @{$v->{profiles}}).']');
          my $e = $app->profiles->setcheck($profile_key, $agent_key, 1, "$v->{subsys} ($v->{version})");
          $app->log->error($e) if $e;

          # check the requested $profile in returned [profiles] array
          my $f = 0;
          for (@{$v->{profiles}}) {
            if ($_ eq $profile_key) { $f = 1; last }
          }
          $app->log->error("ERROR: agent profile differ from the requested!") unless $f;

        } else {
          $app->log->error("ERROR: received invalid json from agent!");
          my $e = $app->profiles->setcheck($profile_key, $agent_key, 0, 'Ошибка формата');
          $app->log->error($e) if $e;

        }
      } else {
        $app->log->error("ERROR: received invalid response from agent!");
        my $e = $app->profiles->setcheck($profile_key, $agent_key, 0, 'Неверные данные');
        $app->log->error($e) if $e;

      }
    })->catch(sub {
      my $err = shift;
      $app->log->error("ERROR: $err");
      my $e = $app->profiles->setcheck($profile_key, $agent_key, 0, $err);
      $app->log->error($e) if $e;

    })->wait;
  });
  return 1;
}


1;
