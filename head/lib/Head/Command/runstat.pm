package Head::Command::runstat;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Manually run traffic statistics collection for <profile>';
has usage => "Usage: APPLICATION runstat <profile>\n";

sub run {
  my ($self, $p) = @_;
  my $app = $self->app;
  croak("Bad <profile> argument\n") unless (defined $p);

  my $profile = $app->config('profiles')->{$p};
  croak("Given <profile> is not found in config file!\n") unless (defined $profile);

  # loop by agents
  for my $agent (@{$profile->{agents}}) {
    my $t = $agent->{type};

    # agents that support runstat
    if ($t eq 'gwsyn' or $t eq 'fwsyn') {
      $app->log->info("$p agent $t: Initiate traffic statistics collection.");

      $app->ua->post("$agent->{url}/runstat" =>
        sub {
          my ($ua, $tx) = @_;
          my $res = eval { $tx->result };
          if (defined $res) {
            if ($res->is_success) {
              # successful update
              $app->log->info("Successful.");

            } else {
              # request error 50x
              $app->log->error("Runstat request error: ".$res->body) if $res->is_error;
            }
          } else {
            # connection failed
            $app->log->error("Connection to agent failed: $@");
          }
        }
      );
    } else {
      $app->log->info("$p agent $t: Agent doesn't support traffic statistics collection.");
    }
  } # agents loop

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}

1;
