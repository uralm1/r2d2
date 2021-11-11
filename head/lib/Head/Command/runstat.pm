package Head::Command::runstat;
use Mojo::Base 'Mojolicious::Command';

use Mojo::URL;
use Head::Ural::Profiles;
#use Carp;

has description => '* Manually run traffic statistics collection for <profile>';
has usage => "Usage: APPLICATION runstat <profile>\n";

sub run {
  my ($self, $p) = @_;
  my $app = $self->app;
  die "Bad <profile> argument\n" unless defined $p;

  # loop by agents
  my $res1 = $app->profiles(dont_copy_config_to_db => 1)->eachagent($p, sub {
    my ($profile_key, $agent_key, $agent) = @_;

    my $t = $agent->{type};

    # agents that support runstat
    if (grep(/^$t$/, @{$app->config('agent_types_stat')})) {
      $app->log->info("$p agent $t: Initiate traffic statistics collection.");

      $app->ua->post(Mojo::URL->new("$agent->{url}/runstat") =>
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
            $app->log->error("Connection to agent failed, probably connect timeout");
          }
        }
      );
    } else {
      $app->log->info("$p agent $t: Agent doesn't support traffic statistics collection.");
    }
  });
  die "Given <profile> is not found!\n" unless $res1;

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}

1;
