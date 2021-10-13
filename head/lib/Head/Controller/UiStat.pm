package Head::Controller::UiStat;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;


sub deviceget {
  my $self = shift;
  my $client_id = $self->stash('client_id');
  return unless $self->exists_and_number404($client_id);
  my $device_id = $self->stash('device_id');
  return unless $self->exists_and_number404($device_id);

  my $rep = $self->param('rep');
  return $self->render(text => 'Bad parameter', status => 503) if defined $rep &&
    !($rep =~ /^(day|month)$/);

  my $j;
  if (!defined $rep || $rep eq 'day') {
    $j = {
      id => $device_id,
      date => '06-10-2021',
      name => 'имя_устройства',
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
      id => $device_id,
      date => '07-10-2021',
      name => 'имя_устройства',
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
