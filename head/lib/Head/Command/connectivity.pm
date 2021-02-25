package Head::Command::connectivity;
use Mojo::Base 'Mojolicious::Command';

#use Carp;
use Mojo::URL;
use Mojo::Promise;

has description => '* Check agents connectivity';
has usage => "Usage: APPLICATION connectivity [<profile>]\n";

sub run {
  my ($self, $p) = @_;
  my $app = $self->app;

  my $profiles = $app->config('profiles');
  if (defined $p) {
    die "Fatal error. Requested profile configuration doesn't exist!\n" unless $profiles->{$p};
    $profiles = { $p => $profiles->{$p} };
  }

  while (my ($profile, $v) = each %$profiles) {
    for my $agent (@{$v->{agents}}) {
      $app->log->info("Checking agent [profile: $profile, type: $agent->{type}, url: $agent->{url}]...");

      $app->ua->get_p(Mojo::URL->new("$agent->{url}/subsys") => {Accept => 'application/json'})->then(sub {
        my $tx = shift;
        my $res = eval { $tx->result };

        if (defined($res) && $res->is_success && (my $v = $res->json)) {
          my $ok = 1;
          for (qw/subsys version profiles/) { $ok = undef unless $v->{$_} }
          $ok = undef if ref($v->{profiles}) ne 'ARRAY';
          if ($ok) {
            $app->log->info("OK: [subsys: $v->{subsys}, version: $v->{version}, profiles: ".join(',', @{$v->{profiles}}).']');
            # check the requested $profile in returned [profiles] array
            my $f = 0;
            for (@{$v->{profiles}}) {
              if ($_ eq $profile) { $f = 1; last }
            }
            $app->log->error("ERROR: agent profile differ from the requested!") unless $f;
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
