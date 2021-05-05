package Head::Controller::UiOplog;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;

sub oplog {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status=>400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 500 per page', status=>400) if $lines_on_page > 500;

  $self->render_later;

  $self->mysql_inet->db->query("SELECT COUNT(*) FROM op_log" =>
    sub {
      my ($db, $err, $results) = @_;
      return $self->render(text => 'Database error, total lines counting', status=>503) if $err;

      my $lines_total = $results->array->[0];
      $results->finish;

      my $num_pages = ceil($lines_total / $lines_on_page);
      return $self->render(text => 'Bad parameter value', status=>400) if $page < 1 ||
        ($num_pages > 0 && $page > $num_pages);

      $db->query("SELECT id, DATE_FORMAT(op_log.date, '%k:%i:%s %e/%m/%y') AS date, subsys, info \
FROM op_log ORDER BY op_log.date DESC, id DESC LIMIT ? OFFSET ?",
$lines_on_page, ($page - 1) * $lines_on_page =>
        sub {
          my ($db, $err, $results) = @_;
          return $self->render(text => 'Database error, retrieving log', status=>503) if $err;

          if (my $j = $results->hashes) {
            $self->render(json => {
              d => $j,
              lines_total => $lines_total,
              pages => $num_pages,
              page => $page,
              lines_on_page => $lines_on_page
            });
          } else {
            $self->render(text => 'Database error, bad result', status=>503);
          }
        }
      ); # inner query
    }
  ); # outer query
}


1;
