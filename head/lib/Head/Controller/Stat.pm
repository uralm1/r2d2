package Head::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub trafstat {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless @$profs;

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j;

    $self->render_later;

    #$self->log->debug($self->dumper($j));

    if ($self->check_workers) {
      # statistics update is high priority task
      $self->minion->enqueue(traf_stat => [time, $profs, $j] => {priority => 5});
    } else {
      my $m = 'Statistics not accepted. Execution subsystem error.';
      $self->log->error($m);
      $self->dblog->error($m);
      return $self->render(text=>"Execution subsystem not available", status=>503);
    }

    # old mechanics
    # update database in single transaction
    my $db = $self->mysql_inet->db;
    my $tx = eval { $db->begin };
    unless ($tx) {
      $self->log->error("Database begin transaction failure: $@");
      return $self->render(text=>"Database begin transaction failure", status=>503);
    }

    $self->_submit_traf_stats($db, $tx, $profs, $j);
    # now exit, execution continue asyncroniously

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


# internal, starts recursive asyncronious submit process
sub _submit_traf_stats {
  my ($self, $db, $tx, $profs, $j, $s) = @_;
  croak 'Bad arguments' unless ($db && $tx && $profs && $j);
  $s //= [0, 0]; # reset counters on first run

  my ($id, $v);
  unless (($id, $v) = each %$j) {
    eval { $tx->commit };
    if ($@) {
      $self->log->error("Database update transaction commit failure $@");
      return $self->render(text=>"Database update transaction failure", status=>503);
    }
    # finished
    my $m = "UPDATE FINISHED, submitted: $s->[0], updated: $s->[1]";
    $self->log->debug($m);
    #$self->dblog->info($m);
    return $self->render(text=>"DONE $s->[1]/$s->[0]", status=>200); # SUCCESS
  }

  my $inb = $v->{in};
  my $outb = $v->{out};
  $s->[0]++; # count submitted
  if ($inb > 0 or $outb > 0) {
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

    $db->query_p("UPDATE clients SET sum_in = sum_in + ?, sum_out = sum_out + ?, \
sum_limit_in = IF(qs != 0, IF(sum_limit_in > ?, sum_limit_in - ?, 0), sum_limit_in) \
WHERE $rule id = ?", $inb, $outb, $inb, $inb, $id)->then(sub {
      my $results = shift;
      $s->[1] += $results->affected_rows; # count updated
    })->then(sub {
      $self->_submit_traf_stats($db, $tx, $profs, $j, $s);
    })->catch(sub {
      my $err = shift;
      $self->log->error("Database update failure id $id: $err");
      return $self->render(text=>"Database update failure", status=>503);
    });
  } else {
    $self->_submit_traf_stats($db, $tx, $profs, $j, $s);
  }
}


1;
