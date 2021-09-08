package Ui::Controller::Oplog;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;

sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $log_active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($log_active_page);

  $self->render_later;

  $self->ua->get(Mojo::URL->new('/ui/oplog')->to_abs($self->head_url)->
    query({page => $log_active_page, lop => $self->config('log_lines_on_page')}) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(log_rec => $v);
    } # get closure
  );
}


1;
