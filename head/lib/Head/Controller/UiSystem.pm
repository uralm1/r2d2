package Head::Controller::UiSystem;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Time::Piece;
use Head::Ural::Profiles;

sub profilesstatus {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0;
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;

  $self->render_later;

  my $lines_total = scalar keys %{$self->profiles->hash};
  my $num_pages = ceil($lines_total / $lines_on_page);
  return $self->render(text => 'Bad parameter value', status => 503)
    if $page < 1 || ($num_pages > 0 && $page > $num_pages);

  # we have to load checks status from db
  # do this asyncronously
  $self->profiles->loadchecks_p()
  ->then(sub {
    $self->profiles->handle_loadchecks(@_); # always success

  })->then(sub {
    my $j = []; # resulting d attribute

    $self->profiles->each(sub {
      my ($key, $prof) = @_;
      my $p_rec = {
        key => $key,
        name => $prof->{name},
        lastcheck => $prof->{lastcheck} // '',
        agents => []
      };

      for my $agent (values %{$prof->{agents}}) {
        my $a_rec = {};
        for (qw/name type url state status/) {
          die 'Agent attribute error' unless defined $agent->{$_};
          $a_rec->{$_} = $agent->{$_};
        }
        $a_rec->{lastcheck} = $agent->{lastcheck} // '';

        push @{$p_rec->{agents}}, $a_rec;
      }

      push @$j, $p_rec;
    });

    #say $self->dumper($j);
    $self->render(json => {
      d => $j,
      lines_total => $lines_total,
      pages => $num_pages,
      page => $page,
      lines_on_page => $lines_on_page
    });

  })->catch(sub {
    my $err = shift;
    $self->log->error($err);
    $self->render(text => 'Database error, loading profiles status', status => 503);
  });
}


sub profileshash {
  my $self = shift;

  my $j = {};
  $self->profiles->each(sub {
    my ($profile_key, $profile) = @_;
    $j->{$profile_key} = $profile->{name};
  });

  $self->render(json => $j);
}


1;
