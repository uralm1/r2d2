package Head::Command::runstat;
use Mojo::Base 'Mojolicious::Command';

use Mojo::URL;
use Mojo::Util qw(getopt);
use Head::Ural::Profiles qw(split_agent_subsys);
#use Carp;

has description => '* Manually run traffic statistics collection for <profile>';
has usage => "Usage: APPLICATION runstat <profile>\n";

sub run {
  my $app = shift->app;

  #getopt \@_, 'cron'=>\my $cron
  #  or die "Error in commandline arguments\n";

  my ($p) = @_;
  die "Bad <profile> argument\n" unless defined $p;

  # loop by agents
  my $e = eval { $app->profiles->exist($p) };
  if (!defined $e) {
    die "Database error (exist)!\n";
  } elsif (!$e) {
    die "Given profile $p is not found!\n";
  } else {
    my $res1 = eval { $app->profiles->eachagent($p, sub {
      my ($profile_key, $agent_key, $agent) = @_;

      my $type_subsys = $agent->{type};
      my ($t) = split_agent_subsys($type_subsys);

      # agents that support runstat
      if (grep(/^$t$/, @{$app->config('agent_types_stat')})) {
        $app->log->info("$p agent $type_subsys: Initiate traffic statistics collection.");

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
        $app->log->info("$p agent $type_subsys: Agent doesn't support traffic statistics collection.");
      }
    }) };
    die "Database error (eachagent)!\n" unless $res1;
  }

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

  return 0;
}

1;
