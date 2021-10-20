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

  $device_id = 5; # FIXME

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);

  $self->render_later;

  my $db = $self->mysql_inet->db;

  # promises
  my $dev_p = $db->query_p("SELECT id, name, sum_in, sum_out, qs, limit_in, sum_limit_in, blocked, profile \
FROM devices \
WHERE id = ?",
#WHERE id = ? AND client_id = ?",
    $device_id,
    #$client_id
  );
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

  # set handler
  Mojo::Promise->all($dev_p, $today_traf_p, $curmonth_traf_p, $traf_p)
    ->catch(sub {
      my $err = shift;
      return $self->render(text => 'Database error, retrieving device statistics', status => 503);
      
    })->then(sub {
      my ($dev_p, $today_traf_p, $curmonth_traf_p, $traf_p) = @_;
      # TODO
      #
      return $self->render(text => "Not implemented", status => 404);
    });




  ###################################
=for comment
  my $t = localtime;
  my $j = { date => $t->dmy('-') };

  my $results = $db->query("SELECT id, name, sum_in, sum_out, qs, limit_in, sum_limit_in, blocked, profile \
FROM devices \
WHERE id = ?",
#WHERE id = ? AND client_id = ?",
    $device_id,
    #$client_id
  );
  my ($sum_in, $sum_out);

  if (my $rh = $results->hash) {
    $j->{id} = $rh->{id};
    $j->{name} = $rh->{name};
    $j->{profile} = $rh->{profile};
    $j->{limit_in} = $rh->{limit_in};
    $j->{sum_limit_in} = $rh->{sum_limit_in};
    $j->{qs} = $rh->{qs};
    $j->{blocked} = $rh->{blocked};
    $sum_in = $rh->{sum_in};
    $sum_out = $rh->{sum_out};

  } else {
    return $self->render(text => 'Not found', status => 404);
  }
  $results->finish;

  $results = $db->query("SELECT d_in, d_out FROM adaily \
WHERE device_id = ? AND date = CURDATE()",
    $device_id
  );
  if (my $rh = $results->hash) {
    my $h = {};
    _push_r($h, 'in', $sum_in, $rh->{d_in});
    _push_r($h, 'out', $sum_out, $rh->{d_out});
    $j->{today_traf} = $h;
  } else {
    $j->{today_traf} = {in => -1, out => -1};
  }
  $results->finish;

  $results = $db->query("SELECT DAYOFMONTH(date) AS day, m_in, m_out FROM amonthly \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL DAYOFMONTH(CURDATE())-1 DAY) \
ORDER BY date ASC LIMIT 1",
    $device_id
  );
  if (my $rh = $results->hash) {
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

  if (!defined $rep || $rep eq 'day') {

    # get_daily_data

    $results = $db->query("SELECT date, d_in, d_out FROM adaily \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH) \
ORDER BY date DESC",
      $device_id
    );

    my $t = localtime;
    my $daycount = $t->truncate(to => 'day');
    $daycount->date_separator('-');
    my $dayend = $daycount - ONE_DAY * ($t->month_last_day + 1);
    my ($lastin, $lastout);
    $lastin = undef;
    my $recdate = undef;
    my $startflag = 1;
    my $endflag = 0;
    my $traf_arr = [];
    my $next;

    while ($daycount >= $dayend) {
      if (!$endflag && !$recdate) {
        if ($next = $results->hash) {
          # use $t to correctly inherit timezone so we can compare objects
          $recdate = $t->strptime($next->{date}, '%Y-%m-%d');
          die 'Date conversion error' unless $recdate;
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
    $results->finish;

    $j->{traf} = $traf_arr;

  } else {

    # get_monthly_data

    $results = $db->query("SELECT date, m_in, m_out FROM amonthly \
WHERE device_id = ? AND date <= CURDATE() AND date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) \
ORDER BY date ASC",
      $device_id
    );
    my $temp_arr = [];
    my $lastdate = undef;
    while (my $next = $results->hash) {
      my $recdate = Time::Piece->strptime($next->{date}, '%Y-%m-%d');
      die 'Date conversion error' unless $recdate;
      $recdate = $recdate->truncate(to => 'day');
      my $recdate_monthtruncated = $recdate->truncate(to => 'month');

      # skip the same month but different dates
      next if defined $lastdate and $recdate_monthtruncated == $lastdate;

      $lastdate = $recdate_monthtruncated;
      push @$temp_arr, { date => $recdate, in => $next->{m_in}, out => $next->{m_out} };
    }
    $results->finish;
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
    my $traf_arr = [];

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

    $j->{traf} = $traf_arr;
  }

  #say $self->dumper($j);
  $self->render(json => $j);
=cut
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

  my $j;
  if (!defined $rep || $rep eq 'day') {
    $j = {
      id => $server_id,
      date => '06-10-2021',
      cn => 'имя_сервера',
      email => 'mailbox@server.tld',
      email_notify => 1,
      qs => 2,
      limit_in => 123456789,
      sum_limit_in => 123456,
      blocked => 0,
      profile => 'plk',
      today_traf => {in => 999, out => 888},
      curmonth_traf => {in => 7777, out => 6666},
      traf => [
        { date => '30-09-2021', in => 999, out => 888},
        { date => '01-10-2021', in => 99912312, out => 888, fuzzy_in=>1},
        { date => '02-10-2021', in => 222, out => 7777345},
        { date => '03-10-2021', in => 999, out => 888},
        { date => '04-10-2021', in => -1, out => -1},
        { date => '20-10-2021', in => 99923442, out => -1, fuzzy_out=>1},
      ],
    };
  } else {
    $j = {
      id => $server_id,
      date => '07-10-2021',
      cn => 'имя_сервера',
      email => 'mailbox@server.tld',
      email_notify => 1,
      qs => 1,
      limit_in => 123456789,
      sum_limit_in => 0,
      blocked => 1,
      profile => 'plk',
      today_traf => {in => 999, out => 888},
      curmonth_traf => {in => 7777, out => 6666},
      traf => [
        { date => '01-06-2021', in => 999, out => 888},
        { date => '01-07-2021', in => 99912312, out => 888, fuzzy_in=>1},
        { date => '01-08-2021', in => 222, out => 7777345},
        { date => '01-09-2021', in => 999, out => 888},
        { date => '01-10-2021', in => -1, out => -1},
        { date => '01-11-2021', in => 99923442, out => -1, fuzzy_out=>1},
      ],
    };
  }

  $self->render(json => $j);
}


sub clientget {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);

  my $j;
  if (!defined $rep || $rep eq 'day') {
    $j = {
      id => $client_id,
      date => '06-10-2021',
      cn => 'фамилия_имя_отчество',
      guid => '',
      login => 'ivanov',
      email => 'ivanov@server.tld',
      email_notify => 1,
      devices => [
        {
          id => 111, #device_id,
          date => '06-10-2021',
          name => 'имя_устройства1',
          qs => 2,
          limit_in => 123456789,
          sum_limit_in => 123456,
          blocked => 0,
          profile => 'plk',
          today_traf => {in => 999, out => 888},
          curmonth_traf => {in => 7777, out => 6666},
          traf => [
            { date => '30-09-2021', in => 999, out => 888},
            { date => '01-10-2021', in => 99912312, out => 888, fuzzy_in=>1},
            { date => '02-10-2021', in => 222, out => 7777345},
            { date => '03-10-2021', in => 999, out => 888},
            { date => '04-10-2021', in => -1, out => -1},
            { date => '20-10-2021', in => 99923442, out => -1, fuzzy_out=>1},
          ],
        },
        {
          id => 222, #device_id,
          date => '06-10-2021',
          name => 'имя_устройства2',
          qs => 2,
          limit_in => 123456789,
          sum_limit_in => 123456,
          blocked => 0,
          profile => 'plk',
          today_traf => {in => 999, out => 888},
          curmonth_traf => {in => 7777, out => 6666},
          traf => [
            { date => '30-09-2021', in => 999, out => 888},
            { date => '01-10-2021', in => 99912312, out => 888, fuzzy_in=>1},
            { date => '02-10-2021', in => 222, out => 7777345},
            { date => '03-10-2021', in => 999, out => 888},
            { date => '04-10-2021', in => -1, out => -1},
            { date => '20-10-2021', in => 99923442, out => -1, fuzzy_out=>1},
          ],
        },
      ]
    };
  } else {
    $j = {
      id => $client_id,
      date => '07-10-2021',
      cn => 'фамилия_имя_отчество',
      guid => '',
      login => 'ivanov',
      email => 'ivanov@server.tld',
      email_notify => 1,
      devices => [
        {
          id => 111, #device_id,
          date => '07-10-2021',
          name => 'имя_устройства1',
          qs => 1,
          limit_in => 123456789,
          sum_limit_in => 0,
          blocked => 1,
          profile => 'plk',
          today_traf => {in => 999, out => 888},
          curmonth_traf => {in => 7777, out => 6666},
          traf => [
            { date => '01-06-2021', in => 999, out => 888},
            { date => '01-07-2021', in => 99912312, out => 888, fuzzy_in=>1},
            { date => '01-08-2021', in => 222, out => 7777345},
            { date => '01-09-2021', in => 999, out => 888},
            { date => '01-10-2021', in => -1, out => -1},
            { date => '01-11-2021', in => 99923442, out => -1, fuzzy_out=>1},
          ],
        },
        {
          id => 222, #device_id,
          date => '07-10-2021',
          name => 'имя_устройства2',
          qs => 1,
          limit_in => 123456789,
          sum_limit_in => 0,
          blocked => 1,
          profile => 'plk',
          today_traf => {in => 999, out => 888},
          curmonth_traf => {in => 7777, out => 6666},
          traf => [
            { date => '01-06-2021', in => 999, out => 888},
            { date => '01-07-2021', in => 99912312, out => 888, fuzzy_in=>1},
            { date => '01-08-2021', in => 222, out => 7777345},
            { date => '01-09-2021', in => 999, out => 888},
            { date => '01-10-2021', in => -1, out => -1},
            { date => '01-11-2021', in => 99923442, out => -1, fuzzy_out=>1},
          ],
        },
      ]
    };
  }

  $self->render(json => $j);
}


1;
