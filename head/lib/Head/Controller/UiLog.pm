package Head::Controller::UiLog;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;
use Mojo::Promise;

sub oplog {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status=>400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 500 per page', status=>400) if $lines_on_page > 500;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  my ($lines_total, $num_pages);

  $db->query_p("SELECT COUNT(*) FROM op_log")
  ->then(sub {
    my $results = shift;
    $lines_total = $results->array->[0];
    $results->finish;

    $num_pages = ceil($lines_total / $lines_on_page);
    return Mojo::Promise->reject('Bad parameter value') if $page < 1 ||
      ($num_pages > 0 && $page > $num_pages);

    $db->query_p("SELECT id, DATE_FORMAT(op_log.date, '%k:%i:%s %e/%m/%y') AS date, subsys, info \
FROM op_log ORDER BY op_log.date DESC, id DESC LIMIT ? OFFSET ?",
      $lines_on_page, ($page - 1) * $lines_on_page);

  })->then(sub {
    my $results = shift;
    if (my $j = $results->hashes) {
      $self->render(json => {
        d => $j,
        lines_total => $lines_total,
        pages => $num_pages,
        page => $page,
        lines_on_page => $lines_on_page
      });
    } else {
      Mojo::Promise->reject('oplog bad result');
    }

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad parameter value/i) {
      $self->render(text => $err, status=>400);
    } elsif ($err =~ /oplog bad result/i) {
      $self->render(text => "Database error, $err", status=>503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, oplog', status=>503);
    }
  });
}


sub auditlog {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status=>400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 500 per page', status=>400) if $lines_on_page > 500;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  my ($lines_total, $num_pages);

  $db->query_p("SELECT COUNT(*) FROM audit_log")
  ->then(sub {
    my $results = shift;
    $lines_total = $results->array->[0];
    $results->finish;

    $num_pages = ceil($lines_total / $lines_on_page);
    return Mojo::Promise->reject('Bad parameter value') if $page < 1 ||
      ($num_pages > 0 && $page > $num_pages);

    $db->query_p("SELECT id, DATE_FORMAT(audit_log.date, '%k:%i:%s %e/%m/%y') AS date, login, info \
FROM audit_log ORDER BY audit_log.date DESC, id DESC LIMIT ? OFFSET ?",
      $lines_on_page, ($page - 1) * $lines_on_page);

  })->then(sub {
    my $results = shift;
    if (my $j = $results->hashes) {
      $self->render(json => {
        d => $j,
        lines_total => $lines_total,
        pages => $num_pages,
        page => $page,
        lines_on_page => $lines_on_page
      });
    } else {
      Mojo::Promise->reject('auditlog bad result');
    }

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad parameter value/i) {
      $self->render(text => $err, status=>400);
    } elsif ($err =~ /auditlog bad result/i) {
      $self->render(text => "Database error, $err", status=>503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, auditlog', status=>503);
    }
  });
}


1;
