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
  if ($set =~ /^v$/) {
    if ($view_mode =~ /^(?:|clients|lost|pain|servers)$/) {
      $sort_mode = '' if $sort_mode !~ /^(?:|cn|login)$/;
      $search = '';

    } elsif ($view_mode =~ /^(?:devices|flagged|blocked)$/) {
      $sort_mode = '' if $sort_mode !~ /^(?:|ip|mac|place|rt)$/;
      $search = '';

    }
  } elsif ($set =~ /^sort$/) {
    if ($sort_mode =~ /^(?:cn|login)$/) {
      $view_mode = '' if $view_mode !~ /^(?:|clients|lost|pain|servers)$/;
      $search = '' if _isipmac($search);

    } elsif ($sort_mode =~ /^(?:ip|mac|place|rt)$/) {
      $view_mode = 'devices' if $view_mode !~ /^(?:devices|flagged|blocked)$/;
      $search = '' if _istext($search);

    }
  } else {
    # searching
    if (_isipmac($search)) {
      $view_mode = 'devices';
      $sort_mode = '' if $sort_mode !~ /^(?:|ip|mac|place|rt)$/;

    } elsif (_istext($search)) {
      $view_mode = '';
      $sort_mode = '' if $sort_mode !~ /^(?:|cn|login)$/;

    }
  }

  my $active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($active_page);

  my $lostonlyifexist_mode = $self->session('lostfirstshown') || (defined $search && $search ne '') || $view_mode ne '' ? 0 : 1;

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

      $self->stash(s => $search, v => $view_mode, sort => $sort_mode);
      return $self->render(rec => $v);
    } # get closure
  );
}


# internal
sub _isipmac {
  my $s = shift;
  defined $s && ($s =~ /^$RE{net}{IPv4}$/ || $s =~ /^$RE{net}{MAC}$/);
}

# internal
sub _istext {
  my $s = shift;
  defined $s && $s ne '' && $s !~ /^$RE{net}{IPv4}$/ && $s !~ /^$RE{net}{MAC}$/;
}


1;
