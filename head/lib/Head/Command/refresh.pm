package Head::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw(getopt);
use Mojo::URL;
use Head::Ural::Profiles;
use Carp;

has description => '* Manually refresh device by <id>';
has usage => "Usage: APPLICATION refresh <device-id>\n";

sub run {
  my $app = shift->app;

  #getopt \@_, 'cron'=>\my $cron
  #  or die "Error in commandline arguments\n";

  my ($id) = @_;
  die "Bad <device-id> argument.\n" unless defined($id) && $id =~ /^\d+$/;

  my $profiles = $app->profiles;
  my $db = $app->mysql_inet->db;

  $app->log->info('Manual refresh initiated');

  my $results = eval { $db->query("SELECT profile FROM devices WHERE id = ?", $id) };
  die "Database operation error: $@\n" unless $results;

  my $n = $results->hash;
  #say "profile: $n->{profile}";
  # loop by agents
  my $e = eval { $profiles->exist($n->{profile}) };
  if (!defined $e) {
    die "Refresh failed, database error (exist).\n";
  } elsif (!$e) {
    die "Refresh device id $id failed: invalid profile.\n";
  } else {
    my $res = eval { $profiles->eachagent($n->{profile}, sub {
     my ($profile_key, $agent_key, $agent) = @_;

     eval { refresh_id($app, $agent->{url}, $id) };
     if ($@) {
       chomp $@;
       $app->log->error($@);
     }

    }) };
    die "Refresh failed, database error (eachagent).\n" unless $res;

  }

  return 0;
}


# send refresh request to agent
# refresh_id($app, $agent_url, $device_id);
# dies on error
sub refresh_id {
  my ($app, $agent_url, $id) = @_;
  croak 'Bad arguments' unless $app and $agent_url and $id;

  my $m = "REFRESH device id $id [$agent_url]";
  $app->log->info($m);
  $app->dblog->info($m, sync=>1);

  my $res = eval {
    $app->ua->post(Mojo::URL->new("$agent_url/refresh/$id"))->result;
  };
  # connection to agent failed
  die "Connection to agent [$agent_url] failed: $@\n" unless defined $res;

  if ($res->is_success) {
    # successful post
    my $m = "Device id $id refresh request successfully received by agent [$agent_url]".($res->body ? ': '.$res->body : '');
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

  } else {
    # request error 503
    die "Device id $id error: ".$res->body."\n" if $res->is_error;
  }
  return 1;
}


1;
