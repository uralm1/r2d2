package Head::Controller::UiList;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;
use NetAddr::IP::Lite;
use Mojo::JSON qw(decode_json);
use Mojo::Promise;

sub list {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;

  $self->render_later;

  my $db = $self->mysql_inet->db; # we'll use same connection
  my $q_count = $db->query_p('SELECT COUNT(*) FROM clients');
  my $q_clients = $db->query_p("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, cn, email, email_notify \
FROM clients c \
ORDER BY id ASC LIMIT ? OFFSET ?", $lines_on_page, ($page - 1) * $lines_on_page);
  Mojo::Promise->all($q_count, $q_clients)->then(sub {
    my ($q_count, $q_clients) = @_;

    my $lines_total = $q_count->[0]->array->[0];
    my $num_pages = ceil($lines_total / $lines_on_page);
    return $self->render(text => 'Bad parameter value', status => 400) if $page < 1 ||
      ($num_pages > 0 && $page > $num_pages);

    my $j = [];
    while (my $next = $q_clients->[0]->hash) {
      my $cl = eval { Head::Controller::UiClients::_build_client_rec($next) };
      return $self->render(text => 'Client attribute error', status => 503) unless $cl;

      my $results = eval { $db->query("SELECT id, name, d.desc, DATE_FORMAT(create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
FROM devices d WHERE client_id = ? \
ORDER BY id ASC LIMIT 20", $cl->{id}) };
      return $self->render(text => "Database error, retrieving devices: $@", status => 503) unless $results;
      my $devs = undef;
      if (my $d = $results->hashes) {
        $devs = $d->map(sub { return eval { Head::Controller::UiDevices::_build_device_rec($_) } })->compact;
      } else {
        return $self->render(text => 'Database error, bad result', status=>503);
      }

      $cl->{devices} = $devs;
      push @$j, $cl;
    }

    $self->render(json => {
      d => $j,
      lines_total => $lines_total,
      pages => $num_pages,
      page => $page,
      lines_on_page => $lines_on_page
    });

  })->catch(sub {
    my $err = shift;
    $self->render(text => "Database error: $err", status=>503) if $err;
  });
}


1;
