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
        { date => '30-09-2021', t => {in => 999, out => 888}},
        { date => '01-10-2021', t => {in => 99912312, out => 888, fuzzy_in=>1}},
        { date => '02-10-2021', t => {in => 222, out => 7777345}},
        { date => '03-10-2021', t => {in => 999, out => 888}},
        { date => '04-10-2021', t => {in => -1, out => -1}},
        { date => '20-10-2021', t => {in => 99923442, out => -1, fuzzy_out=>1}},
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
        { date => '06-2021', t => {in => 999, out => 888}},
        { date => '07-2021', t => {in => 99912312, out => 888, fuzzy_in=>1}},
        { date => '08-2021', t => {in => 222, out => 7777345}},
        { date => '09-2021', t => {in => 999, out => 888}},
        { date => '10-2021', t => {in => -1, out => -1}},
        { date => '11-2021', t => {in => 99923442, out => -1, fuzzy_out=>1}},
      ],
    };
  }

  $self->render(json => $j);
}


1;
