package Head::Command::connectivity;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::Promise;

has description => '* Check agents connectivity';
has usage => "Usage: APPLICATION connectivity [<profile>]\n";

sub run {
  my ($self, $p) = @_;
  my $app = $self->app;

  my $profiles = $app->config('profiles');
  if (defined $p) {
    die "Fatal error. Your profile doesn't exist!\n" unless $profiles->{$p};
    $profiles = { $p => $profiles->{$p} };
  }

  while (my ($profile, $v) = each %$profiles) {
    for my $agent (@{$v->{agents}}) {
      $app->log->info("Checking agent [profile: $profile, type: $agent->{type}, url: $agent->{url}]...");

      $app->ua->get_p("$agent->{url}/subsys" => {Accept => 'application/json'})->then(sub {
        my $tx = shift;
        my $res = eval { $tx->result };

        if (defined($res) && $res->is_success && (my $v = $res->json)) {
          my $ok = 1;
          for (qw/subsys version profile/) { $ok = undef unless $v->{$_} }
          if ($ok) {
            $app->log->info("OK: [subsys: $v->{subsys}, version: $v->{version}, profile: $v->{profile}]");
            $app->log->error("ERROR: agent profile differ from the requested!") if ($v->{profile} ne $profile);
          } else {
            $app->log->error("ERROR: received invalid json from agent!");
          }
        } else {
          $app->log->error("ERROR: received invalid response from agent!");
        }
      })->catch(sub {
        my $err = shift;
        $app->log->error("ERROR: $err");

      })->wait;
    } # agents loop

  } # profiles loop

  return 1;
}


1;
