package Ui::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Regexp::Common qw(net);

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $search = $self->param('s');
  my $view_mode = $self->param('v') // '';
  my $sort_mode = $self->param('sort') // '';
  my $set = $self->param('set') // 'v';

  # consistency
  # (1)
  if (_isip($search)) {
    $view_mode = 'devices' if $view_mode !~ /^(?:devices|flagged)$/;
    $sort_mode = '' if $sort_mode !~ /^(?:|ip|place|rt)$/;

  } elsif (_istext($search)) {
    $view_mode = '' if $view_mode !~ /^(?:|clients|lost|pain|servers)$/;
    $sort_mode = '' if $sort_mode !~ /^(?:|cn|login)$/;

  }
  if ($set =~ /^v$/) {
    # (2)
    if ($view_mode =~ /^(?:|clients|lost|pain|servers)$/) {
      $sort_mode = '' if $sort_mode !~ /^(?:|cn|login)$/;

    } elsif ($view_mode =~ /^(?:devices|flagged)$/) {
      $sort_mode = '' if $sort_mode !~ /^(?:|ip|place|rt)$/;

    }

  } elsif ($set =~ /^sort$/) {
    # (3)
    if ($sort_mode =~ /^(?:cn|login)$/) {
      $view_mode = '' if $view_mode !~ /^(?:|clients|lost|pain|servers)$/;
      $search = '' if _isip($search);

    } elsif ($sort_mode =~ /^(?:ip|place|rt)$/) {
      $view_mode = 'devices' if $view_mode !~ /^(?:devices|flagged)$/;
      $search = '' if _istext($search);

    }
  }

  my $active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($active_page);

  my $lostonlyifexist_mode = (defined $search && $search ne '') || $view_mode ne '' ? 0 : 1;

  $self->render_later;

  $self->ua->get(Mojo::URL->new('/ui/list')->to_abs($self->head_url)->
    query({page => $active_page, lop => $self->config('lines_on_page'),
      s => $search,
      v => $view_mode,
      sort => $sort_mode,
      lostonlyifexist => $lostonlyifexist_mode}) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(rec => $v);
    } # get closure
  );
}


# internal
sub _isip {
  my $s = shift;
  defined $s && ($s =~ /^$RE{net}{IPv4}$/ || $s =~ /^$RE{net}{MAC}$/);
}

# internal
sub _istext {
  my $s = shift;
  defined $s && $s ne '';
}


1;
