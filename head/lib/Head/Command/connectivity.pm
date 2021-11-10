package Head::Command::connectivity;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::URL;
use Mojo::Promise;
use Time::Piece;

has description => '* Check agents connectivity (run from cron cmd)';
has usage => "Usage: APPLICATION connectivity [<profile>]\n";

sub run {
  my ($self, $p) = @_;
  my $app = $self->app;

  my $profiles = $app->profiles(dont_copy_config_to_db => 1)->hash;
  if (defined $p) {
    die "Fatal error. Requested profile configuration doesn't exist!\n" unless $profiles->{$p};
  }

  # undefined $p means - all profiles
  $app->profiles->eachagent($p, sub {
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


# internal
sub _update_lastcheck {
  my $t = localtime;
  $_[0]->{lastcheck} = $t->hms.' '.$t->dmy;
}


1;
