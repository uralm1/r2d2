package Head::Controller::UiSystem;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Time::Piece;
use Mojo::Promise;
use Head::Ural::Profiles;
use Head::Ural::SyncQueue;

sub profilesstatus {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;
  #$self->stash(page => $page, lines_on_page => $lines_on_page);

  $self->render_later;

  my $profiles = $self->profiles;
  $profiles->count_p
  ->then(sub {
    my $lines_total = $_[0];
    my $num_pages = ceil($lines_total / $lines_on_page);
    return Mojo::Promise->reject('Bad parameter value') if $page < 1 || ($num_pages > 0 && $page > $num_pages);

    $self->stash(lines_total => $lines_total, num_pages => $num_pages);

    $profiles->status_p($lines_on_page, $page);

  })->then(sub {
    my $j = shift;
    #say $self->dumper($j);
    $self->render(json => {
      d => $j,
      lines_total => $self->stash('lines_total'),
      pages => $self->stash('num_pages'),
      page => $page,
      lines_on_page => $lines_on_page
    });

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad parameter value/i) {
      $self->render(text => $err, status => 400);
    } elsif ($err =~ /^system profile attribute error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => 'Database error, loading profiles status', status => 503);
    }
  });
}


sub profileshash {
  my $self = shift;

  $self->render_later;

  $self->profiles->hash_p
  ->then(sub {
    $self->render(json => $_[0]);

  })->catch(sub {
    my $err = shift;
    $self->render(text => "Database error, querying profiles: $err", status => 503);
  });
}


sub syncqueuestatus {
  my $self = shift;

  $self->render_later;

  $self->syncqueue->status_p
  ->then(sub {
    $self->render(json => $_[0]);

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad result/i) {
      $self->render(text => 'Database error, bad result', status => 503);
    } else {
      $self->render(text => "Database error, querying syncqueue: $err", status => 503);
    }
  });
}


1;
