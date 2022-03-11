package Head::Controller::UiStat;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use Mojo::Promise;
use Time::Piece;
use Time::Seconds;

sub deviceget {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);
  $self->stash(rep => $rep);

  $self->render_later;

  my $db = $self->mysql_inet->db;

  $self->stash(j => {}); # resulting json

  $self->device_attrs_p($db, $device_id, $client_id)
  ->then(sub {
    $self->device_traf_p($db, $device_id);

  })->then(sub {
    my $j = $self->stash('j');
    #say $self->dumper($j);
    $self->render(json => $j);

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^not found/i) {
      $self->render(text => $err, status => 404);
    } elsif ($err =~ /^date conversion error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, retrieving device stats', status => 503);
    }
  });
}


# $promise = $self->device_attrs_p($db, $device_id, $client_id)
#
# $self->device_attrs_p($db, $device_id, $client_id)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub device_attrs_p {
  my ($self, $db, $device_id, $client_id) = @_;

  $db->query_p("SELECT d.id, d.name, sum_in, sum_out, defjump, qs, limit_in, sum_limit_in, blocked, d.profile, p.name AS profile_name \
FROM devices d LEFT OUTER JOIN profiles p ON d.profile = p.profile \
WHERE d.id = ? AND d.client_id = ?",
    $device_id,
    $client_id)
  ->then(sub {
    my $result = shift;

    my $j = $self->stash('j');
    my $t = localtime;
    $j->{date} = $t->dmy('-');

    if (my $rh = $result->hash) {
      for (qw/id name limit_in sum_limit_in defjump qs blocked profile/) {
        die 'Undefined device attribute' unless exists $rh->{$_};
        $j->{$_} = $rh->{$_};
      }
      for (qw/profile_name/) {
        $j->{$_} = $rh->{$_} if defined $rh->{$_};
      }
      for (qw/sum_in sum_out/) {
        die 'Undefined device stat attribute' unless exists $rh->{$_};
      }
      $self->stash(
        sum_in => $rh->{sum_in} // 0,
        sum_out => $rh->{sum_out} // 0
      );
      # success
      return 1;

    } else {
      Mojo::Promise->reject('Not found');
    }
  });
}


# $promise = $self->device_traf_p($db, $device_id)
#
# $self->device_traf_p($db, $device_id)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub device_traf_p {
  my ($self, $db, $device_id) = @_;

  $self->_device_traf_p($db, $device_id)
  ->then(sub {
    my ($today_traf_p, $curmonth_traf_p, $traf_p) = @_;

    my $j = $self->stash('j');
    my $sum_in = $self->stash('sum_in');
    my $sum_out = $self->stash('sum_out');

    if (my $rh = $today_traf_p->[0]->hash) {
      my $h = {};
      _push_r($h, 'in', $sum_in, $rh->{d_in});
      _push_r($h, 'out', $sum_out, $rh->{d_out});
      $j->{today_traf} = $h;
    } else {
      $j->{today_traf} = {in => -1, out => -1};
    }

    if (my $rh = $curmonth_traf_p->[0]->hash) {
      my $h = {};
      _push_r($h, 'in', $sum_in, $rh->{m_in});
      _push_r($h, 'out', $sum_out, $rh->{m_out});
      if ($rh->{day} != 1) {
        $h->{fuzzy_in} = 1;
        $h->{fuzzy_out} = 1;
      }
      $j->{curmonth_traf} = $h;
    } else {
      $j->{curmonth_traf} = {in => -1, out => -1};
    }

    my $traf_arr = [];

    my $rep = $self->stash('rep');
    if (!defined $rep || $rep eq 'day') {
      # get_daily_data
      my $ret = _process_daily_data($traf_p->[0], $traf_arr);
      return Mojo::Promise->reject($ret) if $ret ne q{};

    } else {
      # get_monthly_data
      my $ret = _process_monthly_data($traf_p->[0], $traf_arr);
      return Mojo::Promise->reject($ret) if $ret ne q{};
    }

    $j->{traf} = $traf_arr;
    # success
    return 1;
  });
}


# $all_db_promise = $self->_device_traf_p($db, $device_id)
sub _device_traf_p {
  my ($self, $db, $device_id) = @_;

  # promises
  my $today_traf_p = $db->query_p("SELECT d_in, d_out FROM adaily \
WHERE device_id = ? AND date = CURDATE()",
    $device_id
  );
  my $curmonth_traf_p = $db->query_p("SELECT DAYOFMONTH(date) AS day, m_in, m_out FROM amonthly \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL DAYOFMONTH(CURDATE())-1 DAY) \
ORDER BY date ASC LIMIT 1",
    $device_id
  );

  my $traf_p;
  my $rep = $self->stash('rep');
  if (!defined $rep || $rep eq 'day') {
    # get_daily_data
    $traf_p = $db->query_p("SELECT date, d_in, d_out FROM adaily \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH) \
ORDER BY date DESC",
      $device_id
    );
  } else {
    # get_monthly_data
    $traf_p = $db->query_p("SELECT date, m_in, m_out FROM amonthly \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) \
ORDER BY date ASC",
      $device_id
    );
  }

  # return compound promise
  Mojo::Promise->all($today_traf_p, $curmonth_traf_p, $traf_p);
}


# ''|'error string' = _process_daily_data($traf_db_result, $traf_arr)
sub _process_daily_data {
  my ($traf_db_result, $traf_arr) = @_;

  my $t = localtime;
  my $daycount = $t->truncate(to => 'day');
  $daycount->date_separator('-');
  my $dayend = $daycount - ONE_DAY * ($t->month_last_day + 1);
  my ($lastin, $lastout);
  $lastin = undef;
  my $recdate = undef;
  my $startflag = 1;
  my $endflag = 0;
  my $next;

  while ($daycount >= $dayend) {
    if (!$endflag && !$recdate) {
      if ($next = $traf_db_result->hash) {
        # use $t to correctly inherit timezone so we can compare objects
        $recdate = $t->strptime($next->{date}, '%Y-%m-%d');
        return 'Date conversion error' unless $recdate;

        $recdate = $recdate->truncate(to => 'day');
      } else {
        $endflag = 1;
      }
    }

    #say "loop daycount: $daycount, recdate: $recdate";
    if (!$endflag && $daycount == $recdate) {
      if (defined $lastin) {
        my $h = { date => $daycount->dmy };
        _push_r($h, 'in', $lastin, $next->{d_in} // 0);
        _push_r($h, 'out', $lastout, $next->{d_out} // 0);
        push @$traf_arr, $h;
      } else {
        if (!$startflag) {
          push @$traf_arr, { date => $daycount->dmy, in => -1, out => -1 };
        } else {
          $startflag = 0;
        }
      }
      $lastin = $next->{d_in};
      $lastout = $next->{d_out};
      $recdate = undef;

    } else {
      if (!$startflag) {
        push @$traf_arr, { date => $daycount->dmy, in => -1, out => -1 };
      } else {
        $startflag = 0;
      }
      $lastin = undef;
    }
    $daycount -= ONE_DAY;
  }
  return '';
}


# ''|'error string' = _process_monthly_data($traf_db_result, $traf_arr)
sub _process_monthly_data {
  my ($traf_db_result, $traf_arr) = @_;

  my $temp_arr = [];
  my $lastdate = undef;
  while (my $next = $traf_db_result->hash) {
    my $recdate = Time::Piece->strptime($next->{date}, '%Y-%m-%d');
    return 'Date conversion error' unless $recdate;

    $recdate = $recdate->truncate(to => 'day');
    my $recdate_monthtruncated = $recdate->truncate(to => 'month');

    # skip the same month but different dates
    next if defined $lastdate and $recdate_monthtruncated == $lastdate;

    $lastdate = $recdate_monthtruncated;
    push @$temp_arr, { date => $recdate, in => $next->{m_in}, out => $next->{m_out} };
  }
  #say "date: $_->{date}, in: $_->{in}, out: $_->{out}" for (@$temp_arr);

  my $t = localtime;
  my $daycount = $t->truncate(to => 'month'); # YYYY-MM-01
  $daycount->date_separator('-');
  my $dayend = $daycount->add_years(-1);
  my ($lastin, $lastout);
  $lastin = undef;
  my $recdate = undef;
  my ($recdate_year, $recdate_month, $recdate_day, $in, $out);
  my $startflag = 1;
  my $endflag = 0;
  my $lastroundflag = 0;

  my $i = $#$temp_arr; # array index from last to first
  while ($daycount >= $dayend) {
    if (!$endflag && !$recdate) {
      if ($i >= 0) {
        my $th = $temp_arr->[$i];
        $recdate = $th->{date};
        $recdate_year = $recdate->year;
        $recdate_month = $recdate->mon;
        $recdate_day = $recdate->mday;
        $in = $th->{in};
        $out = $th->{out};
        $i--;
      } else {
        $endflag = 1;
      }
    }

    if (!$endflag && $recdate_month == $daycount->mon && $recdate_year == $daycount->year) {
      if (defined $lastin) {
        my $h = { date => $daycount->dmy };
        _push_r($h, 'in', $lastin, $in // 0);
        _push_r($h, 'out', $lastout, $out // 0);
        if ($lastroundflag || $recdate_day != 1) {
          $h->{fuzzy_in} = 1;
          $h->{fuzzy_out} = 1;
        }
        push @$traf_arr, $h;
      } else {
        if (!$startflag) {
          push @$traf_arr, { date => $daycount->dmy, in => -1, out => -1 };
        } else {
          $startflag = 0;
        }
      }
      $lastin = $in;
      $lastout = $out;
      $lastroundflag = $recdate_day != 1;
      $recdate = undef;

    } else {
      if (!$startflag) {
        push @$traf_arr, { date => $daycount->dmy, in => -1, out => -1 };
      } else {
        $startflag = 0;
      }
      $lastin = undef;
      $lastroundflag = 0;
    }
    $daycount = $daycount->add_months(-1); # $daycount is always month rounded
  }
  return '';
}


sub _push_r {
  my ($h, $k, $val, $prevval) = @_;
  my $r = $val - $prevval;
  if ($r < 0) {
    $h->{"fuzzy_$k"} = 1;
    $h->{$k} = $val;
  } else {
    $h->{$k} = $r;
  }
}


sub serverget {
  my $self = shift;
  my $server_id = $self->stash('server_id');
  return unless $self->exists_and_number404($server_id);

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);
  $self->stash(rep => $rep);

  $self->render_later;

  my $db = $self->mysql_inet->db;

  $self->stash(j => {}); # resulting json

  $self->server_attrs_p($db, $server_id)
  ->then(sub {
    $self->device_traf_p($db, $self->stash('device_id'));

  })->then(sub {
    my $j = $self->stash('j');
    #say $self->dumper($j);
    $self->render(json => $j);

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^not found/i) {
      $self->render(text => $err, status => 404);
    } elsif ($err =~ /^date conversion error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, retrieving server stats', status => 503);
    }
  });
}


# $promise = $self->server_attrs_p($db, $server_id)
#
# $self->server_attrs_p($db, $server_id)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub server_attrs_p {
  my ($self, $db, $server_id) = @_;

  $db->query_p("SELECT d.id AS deviceid, c.id, cn, email, c.email_notify, \
sum_in, sum_out, defjump, qs, limit_in, sum_limit_in, blocked, d.profile, p.name AS profile_name \
FROM clients c INNER JOIN devices d ON d.client_id = c.id \
LEFT OUTER JOIN profiles p ON d.profile = p.profile \
WHERE type = 1 AND c.id = ?",
    $server_id)
  ->then(sub {
    my $result = shift;

    my $j = $self->stash('j');
    my $t = localtime;
    $j->{date} = $t->dmy('-');

    if (my $rh = $result->hash) {
      for (qw/id cn limit_in sum_limit_in defjump qs blocked profile/) {
        die 'Undefined server attribute' unless exists $rh->{$_};
        $j->{$_} = $rh->{$_};
      }
      for (qw/profile_name/) {
        $j->{$_} = $rh->{$_} if defined $rh->{$_};
      }
      for (qw/email email_notify sum_in sum_out deviceid/) {
        die 'Undefined server stat attribute' unless exists $rh->{$_};
      }
      my $email = $rh->{email};
      if (defined $email && $email ne '') {
        $j->{email} = $email;
        $j->{email_notify} = $rh->{email_notify};
      }
      $self->stash(
        sum_in => $rh->{sum_in} // 0,
        sum_out => $rh->{sum_out} // 0,
        device_id => $rh->{deviceid}
      );
      # success
      return 1;

    } else {
      Mojo::Promise->reject('Not found');
    }
  });
}


sub clientget {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);
  $self->stash(rep => $rep);

  $self->render_later;

  my $db = $self->mysql_inet->db;

  $self->stash(j => {}); # resulting json

  $self->client_attrs_p($db, $client_id)
  ->then(sub {
    $self->devices_attrs_p($db, $client_id);

  })->then(sub {
    $self->devices_trafs_p($db);

  })->then(sub {
    my $j = $self->stash('j');
    #say $self->dumper($j);
    $self->render(json => $j);

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^not found/i) {
      $self->render(text => $err, status => 404);
    } elsif ($err =~ /^date conversion error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, retrieving client stats', status => 503);
    }
  });
}


# $promise = $self->client_attrs_p($db, $client_id)
#
# $self->client_attrs_p($db, $client_id)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub client_attrs_p {
  my ($self, $db, $client_id) = @_;

  $db->query_p("SELECT id, cn, guid, login, email, email_notify \
FROM clients WHERE id = ?",
    $client_id)
  ->then(sub {
    my $result = shift;

    my $j = $self->stash('j');
    my $t = localtime;
    $j->{date} = $t->dmy('-');

    if (my $rh = $result->hash) {
      for (qw/id cn guid login/) {
        die 'Undefined client attribute' unless exists $rh->{$_};
        $j->{$_} = $rh->{$_};
      }
      for (qw/email email_notify/) {
        die 'Undefined client stat attribute' unless exists $rh->{$_};
      }
      my $email = $rh->{email};
      if (defined $email && $email ne '') {
        $j->{email} = $email;
        $j->{email_notify} = $rh->{email_notify};
      }
      # success
      return 1;

    } else {
      return Mojo::Promise->reject('Not found');
    }
  });
}


# $promise = $self->devices_attrs_p($db, $client_id)
#
# $self->devices_attrs_p($db, $client_id)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub devices_attrs_p {
  my ($self, $db, $client_id) = @_;

  $db->query_p("SELECT d.id, d.name, sum_in, sum_out, defjump, qs, limit_in, sum_limit_in, blocked, d.profile, p.name AS profile_name \
FROM devices d LEFT OUTER JOIN profiles p ON d.profile = p.profile \
WHERE d.client_id = ? \
ORDER BY d.id ASC LIMIT 100",
    $client_id)
  ->then(sub {
    my $result = shift;

    my $j = $self->stash('j');
    $j->{devices} = [];

    my $dev_sums = [];

    while (my $next = $result->hash) {
      my $dev = {};

      my $t = localtime;
      $dev->{date} = $t->dmy('-');

      for (qw/id name limit_in sum_limit_in defjump qs blocked profile/) {
        die 'Undefined devices attribute' unless exists $next->{$_};
        $dev->{$_} = $next->{$_};
      }
      for (qw/profile_name/) {
        $dev->{$_} = $next->{$_} if defined $next->{$_};
      }

      push @{$j->{devices}}, $dev;

      for (qw/sum_in sum_out/) {
        die 'Undefined devices stat attribute' unless exists $next->{$_};
      }
      push @$dev_sums, {
        sum_in => $next->{sum_in} // 0,
        sum_out => $next->{sum_out} // 0
      }
    }
    $self->stash(devices_sums => $dev_sums);
    # success
    return 1;
  });
}


# $promise = $self->devices_trafs_p($db)
#
# $self->devices_trafs_p($db)
# ->then(sub {...values stored to stash...})
# ->catch(sub {my $err = shift;...report $err...});
sub devices_trafs_p {
  my ($self, $db) = @_;
  my $j = $self->stash('j');

  if (@{$j->{devices}}) {
    # return map promise with limited concurrency
    Mojo::Promise->map(
      {concurrency => 1},
      sub { $self->_device_traf_p($db, $_->{id}) },
      @{$j->{devices}})
    ->then(sub {
      my $j = $self->stash('j');
      my $dev_sums = $self->stash('devices_sums');

      my $i = 0;
      for my $dev_traf_p (@_) {
        my $dev = $j->{devices}[$i];

        my $ds = $dev_sums->[$i];
        my $sum_in = $ds->{'sum_in'};
        my $sum_out = $ds->{'sum_out'};

        my ($today_traf_p, $curmonth_traf_p, $traf_p) = @$dev_traf_p;

        if (my $rh = $today_traf_p->[0]->hash) {
          my $h = {};
          _push_r($h, 'in', $sum_in, $rh->{d_in});
          _push_r($h, 'out', $sum_out, $rh->{d_out});
          $dev->{today_traf} = $h;
        } else {
          $dev->{today_traf} = {in => -1, out => -1};
        }

        if (my $rh = $curmonth_traf_p->[0]->hash) {
          my $h = {};
          _push_r($h, 'in', $sum_in, $rh->{m_in});
          _push_r($h, 'out', $sum_out, $rh->{m_out});
          if ($rh->{day} != 1) {
            $h->{fuzzy_in} = 1;
            $h->{fuzzy_out} = 1;
          }
          $dev->{curmonth_traf} = $h;
        } else {
          $dev->{curmonth_traf} = {in => -1, out => -1};
        }

        my $traf_arr = [];

        my $rep = $self->stash('rep');
        if (!defined $rep || $rep eq 'day') {
          # get_daily_data
          my $ret = _process_daily_data($traf_p->[0], $traf_arr);
          return Mojo::Promise->reject($ret) if $ret ne q{};

        } else {
          # get_monthly_data
          my $ret = _process_monthly_data($traf_p->[0], $traf_arr);
          return Mojo::Promise->reject($ret) if $ret ne q{};
        }

        $dev->{traf} = $traf_arr;

        $i++;
      }
      # success
      return 1;
    });
  } else {
    Mojo::Promise->resolve();
  }
}


1;
