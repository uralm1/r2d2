package Head::Controller::UiList;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;
use NetAddr::IP::Lite;
use Mojo::JSON qw(decode_json);

sub list {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;

  $self->render_later;

  $self->mysql_inet->db->query("SELECT SUM(cnt) FROM ( \
SELECT COUNT(*) AS cnt FROM clients INNER JOIN devices ON devices_id = clients.id \
UNION ALL \
SELECT COUNT(*) AS cnt FROM servers INNER JOIN devices ON devices_id = devices.id \
) tbl" =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => "Database error, total lines counting: $err", status=>503) if $err;

      my $lines_total = $results->array->[0];
      $results->finish;

      my $num_pages = ceil($lines_total / $lines_on_page);
      return $self->render(text => 'Bad parameter value', status => 400) if $page < 1 ||
        ($num_pages > 0 && $page > $num_pages);

      $db->query("SELECT CONCAT('{\"t\":\"server\",\"id\":', s.id, '}') AS e1, \
'{}' AS e2 \
FROM servers s INNER JOIN devices d ON s.devices_id = d.id \
ORDER BY s.id ASC LIMIT ? OFFSET ?",
#      $db->query("SELECT s.id, name, s.desc, DATE_FORMAT(s.create_time, '%k:%i:%s %e/%m/%y') AS create_time, \
#ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, profile \
#FROM servers s INNER JOIN devices d ON s.devices_id = d.id \
#ORDER BY s.id ASC LIMIT ? OFFSET ?",
$lines_on_page, ($page - 1) * $lines_on_page =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => 'Database error, retrieving servers', status => 503) if $err;

          if (my $j = $results->hashes) {
            $self->render(json => {
              d => $j->map(sub {
                  [ decode_json($_->{e1}), decode_json($_->{e2}) ]
              }),
              lines_total => $lines_total,
              pages => $num_pages,
              page => $page,
              lines_on_page => $lines_on_page
            });
          } else {
            $self->render(text => 'Database error, bad result', status => 503);
          }
        }
      ); # inner query

    } # outer closure
  ); # outer query
}


1;
