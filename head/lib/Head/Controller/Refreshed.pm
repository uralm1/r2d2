package Head::Controller::Refreshed;
use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Mojo::mysql;
use Head::Ural::Profiles qw(split_agent_subsys);

sub refreshed {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status => 503) unless @$profs;

  return unless my $j = $self->json_content($self->req);
  my $id = $j->{id};
  my $subsys = $j->{subsys};
  return $self->render(text=>'Bad body parameter', status => 503) unless $id and $subsys;

  $self->render_later;

  my $e = eval { $self->remove_sync_flags($profs, $id, $subsys) };
  unless ($e) {
    $self->log->error("Remove sync flags failure $@");
    return $self->render(text=>"Remove sync flags failure", status => 503);
  }
}


# $self->remove_sync_flags($profs, $id, $subsys)
sub remove_sync_flags {
  my ($self, $profs, $id, $subsys) = @_;
  croak 'Bad arguments' unless $profs and $id and $subsys;

  my ($agent_type) = split_agent_subsys($subsys);
  die "device id $id bad subsys parameter $subsys" unless $agent_type;

  my $db = $self->mysql_inet->db;

  my $profile_rule = q{};
  for (@$profs) {
    if ($profile_rule eq q{}) { # first
      $profile_rule = 'profile IN ('.$db->quote($_);
    } else { # second etc
      $profile_rule .= ','.$db->quote($_);
    }
  }
  $profile_rule .= ') AND' if $profile_rule ne q{};
  #$self->log->debug("WHERE rule: *$profile_rule*");

  # delete sync_flags
  $db->query("DELETE sf FROM sync_flags sf \
INNER JOIN profiles_agents a ON sf.agent_id = a.id \
INNER JOIN profiles p ON a.profile_id = p.id \
WHERE $profile_rule \
sf.device_id = ? AND (a.type = ? OR a.type = ?)",
    $id,
    $subsys,
    $agent_type =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        my $m = "Sync flags database removal failed for device id $id, subsys $subsys";
        $self->log->error("$m: $err");
        $self->dblog->error($m);
        return $self->render(text=>"Sync flags database removal failed", status => 503);
      }

      if ($results->affected_rows > 0) {
        $self->dblog->info("Device id $id $subsys refreshed successfully");
      } else {
        $self->dblog->info("Device id $id $subsys refreshed, no flags are deleted");
      }
      $self->rendered(200);
    }
  );
}


1;
