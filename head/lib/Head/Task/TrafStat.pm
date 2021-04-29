package Head::Task::TrafStat;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
use POSIX qw(strftime);

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(traf_stat => sub {
    my ($job, $timestamp, $profs, $j) = @_;
    die 'Bad job parameters' unless defined $timestamp && $profs && $j && ref($profs) eq 'ARRAY' && ref($j) eq 'HASH';
    my $app = $job->app;

    my $m = 'Stats update job ['.join(',', @$profs).'] ['.strftime("%H:%M:%S %d.%m", localtime($timestamp)).']';
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    # update database in single transaction
    my $db = $app->mysql_inet->db;
    my $tx = eval { $db->begin };
    unless ($tx) {
      $m = "Database begin transaction failure: $@";
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
      return $job->fail;
    }

    my ($submitted, $updated) = (0, 0); # counters

    my $rule = ''; # 'profile IN (plk, p2, p2) AND' or ''
    for (@$profs) {
      if ($rule eq '') { # first
        $rule = 'profile IN ('.$db->quote($_);
      } else { # second etc
        $rule .= ','.$db->quote($_);
      }
    }
    $rule .= ') AND' if $rule ne '';
    #$app->log->debug("WHERE rule: *$rule*");

    while (my ($id, $v) = each %$j) {
      my $inb = $v->{in};
      my $outb = $v->{out};
      $submitted++;
      if ($inb > 0 || $outb > 0) {
        my $results = eval { $db->query("UPDATE clients SET sum_in = sum_in + ?, sum_out = sum_out + ?, \
sum_limit_in = IF(qs != 0, IF(sum_limit_in > ?, sum_limit_in - ?, 0), sum_limit_in) \
WHERE $rule id = ?", $inb, $outb, $inb, $inb, $id) };
        if ($results) {
          $updated += $results->affected_rows;
        } else {
          $m = "Database update failure id $id: $@";
          $app->log->error($m);
          $app->dblog->error($m, sync=>1);
          return $job->fail;
        }
      }
    } # loop by submitted clients

    eval { $tx->commit };
    if ($@) {
      $m = "Database update transaction commit failure: $@";
      $app->log->error($m);
      $app->dblog->error($m, sync=>1);
      return $job->fail;
    }

    # finished
    $m = "Stats update finished: $submitted/$updated";
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    my ($selected, $notified, $blocked) = (0, 0, 0); # counters

    # run block check after update
    for my $jid (keys %$j) {
      my $block_results = eval { $db->query("SELECT id, qs, email_notify, notified, profile FROM clients \
WHERE $rule id = ? AND blocked = 0 AND sum_limit_in <= 0 AND qs > 0", $jid) };
      unless ($block_results) {
        $app->log->error("Block: database operation error: $@");
      } else {
        if (my $n = $block_results->hash) {
          $selected++;
          my $id = $n->{id};
          my $qs = $n->{qs};
          if ($qs == 1) {
            # warn(1) client
            if ($n->{email_notify} && !$n->{notified}) {
              $app->log->debug("Client to notify: $id, qs: $qs, $n->{profile}");
              $app->minion->enqueue(notify_client => [$id]);
              $notified++;
            }

          } elsif ($qs == 2 || $qs == 3) {
            # limit(2) or block(3) client
            $app->log->debug("Client to block: $id, qs: $qs, $n->{profile}");
            $app->minion->enqueue(block_client => [$id, $qs, $n->{profile}]);
            $blocked++;

          } else {
            $app->log->error("Unsupported qs $qs for client id $id.");
          }
        } # has one result
      } # select without errors
    } # loop by submitted clients

    # finished
    $m = "Block check finished: $selected/$notified/$blocked";
    $app->log->info($m);
    $app->dblog->info($m, sync=>1);

    $job->finish;
  });
}


1;
