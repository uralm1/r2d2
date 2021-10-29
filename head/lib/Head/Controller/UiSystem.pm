package Head::Controller::UiSystem;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Time::Piece;

sub systemstatus {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;

  $self->render_later;

  my $profiles = $self->config('profiles');
  #say $self->dumper($profiles);
  my $lines_total = scalar keys %$profiles;
  my $num_pages = ceil($lines_total / $lines_on_page);
  return $self->render(text => 'Bad parameter value', status => 503)
    if $page < 1 || ($num_pages > 0 && $page > $num_pages);

  my $j = []; # resulting d attribute

  while (my ($key, $prof) = each %$profiles) {
    my $p_rec = { key => $key };
    $p_rec->{name} = defined $prof->{name} ? $prof->{name} : 'Имя не задано';

    my $t = localtime;
    $p_rec->{lastcheck} = $t->hms.' '.$t->dmy;

    $p_rec->{agents} = [];
    for my $agent (@{$prof->{agents}}) {
      my $a_rec = {};
      $a_rec->{name} = defined $agent->{name} ? $agent->{name} : 'Имя не задано';
      for (qw/type url/) {
        die 'Agent attribute error' unless defined $agent->{$_};
        $a_rec->{$_} = $agent->{$_};
      }
      $a_rec->{lastcheck} = $t->hms.' '.$t->dmy;

      $a_rec->{state} = 1;
      $a_rec->{status} = 'test@host (3.00)';

      push @{$p_rec->{agents}}, $a_rec;
    }

    push @$j, $p_rec;
  }


  say $self->dumper($j);
  $self->render(json => {
    d => $j,
    lines_total => $lines_total,
    pages => $num_pages,
    page => $page,
    lines_on_page => $lines_on_page
  });
}


1;
