package Head::Controller::Blocked;
use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Mojo::mysql;

sub blocked {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless @$profs;

  return unless my $j = $self->json_content($self->req);
  my $id = $j->{id};
  my $qs_op = $j->{qs};
  my $subsys = $j->{subsys};
  return $self->render(text=>'Bad body parameter', status=>503) unless ($id and $subsys and defined $qs_op);

  $self->render_later;

  # notify user if needed
  $self->enqueue_notification($id, $qs_op ? 0 : 1);

  $self->update_blocked_flag($profs, $id, $qs_op, $subsys);
  # the last function renders result
}


# $self->enqueue_notification($id, 0/1)
sub enqueue_notification {
  my ($self, $id, $doing_unblock) = @_;
  croak 'Bad argument' unless $id;

  # retrieve email_notify from db
  $self->mysql_inet->db->query("SELECT c.email_notify \
FROM devices d INNER JOIN clients c ON d.client_id = c.id WHERE d.id = ?", $id
    => sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        my $m = "Error retriving email_notify flag for device id $id from database. Notification not enqueued";
        $self->log->error("$m: $err");
        $self->dblog->error($m);
        return;
      }
      if (my $n = $results->hash) {
        $self->minion->enqueue(notify_client => [$id, $doing_unblock]) if $n->{email_notify};

      } else {
        my $m = "WARNING: Device id $id wasn't found in devices database. Notification not enqueued";
        $self->dblog->error($m);
      }
    } # closure
  );
}


# $self->update_blocked_flag($profs, $id, $qs_op, $subsys)
# renders result on completion
sub update_blocked_flag {
  my ($self, $profs, $id, $qs_op, $subsys) = @_;
  croak 'Bad arguments' unless ($profs and $id and $subsys and defined $qs_op);

  my $db = $self->mysql_inet->db;
  my $rule = '';
  for (@$profs) {
    if ($rule eq '') { # first
      $rule = 'profile IN ('.$db->quote($_);
    } else { # second etc
      $rule .= ','.$db->quote($_);
    }
  }
  $rule .= ') AND' if $rule ne '';
  #$self->log->debug("WHERE rule: *$rule*");

  # start database flag-update that continue in callback
  $db->query("UPDATE devices SET blocked = ? WHERE $rule id = ?", is_blocked($qs_op) ? 1 : 0, $id
    => sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        my $m = "Database blocked flag update failed for device id $id";
        $self->log->error("$m: $err");
        $self->dblog->error($m);
        return $self->render(text=>"Database update failed", status=>503);
      }

      my $op = is_blocked($qs_op) ? 'blocked' : 'unblocked';
      if ($results->affected_rows > 0) {
        $self->dblog->info("Device id $id $subsys $op successfully");
      } else {
        $self->dblog->info("Device id $id $subsys $op but nothing is updated");
      }
      $self->rendered(200);
    } # closure
  );
}


# $bool = is_blocked($qs_op)
sub is_blocked {
  my $qs = shift;
  return $qs == 2 || $qs == 3;
}


1;
