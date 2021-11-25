package Ui::Controller::Clients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $search = $self->param('s');
  my $view_mode = $self->param('v');
  my $sort_mode = $self->param('sort');

  my $active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($active_page);

  my $lostonlyifexist_mode = (defined $search && $search ne '') ||
    (defined $view_mode && $view_mode ne '') ? 0 : 1;

  $self->render_later;

  $self->ua->get(Mojo::URL->new('/ui/list')->to_abs($self->head_url)->
    query({page => $active_page, lop => $self->config('lines_on_page'),
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


1;
