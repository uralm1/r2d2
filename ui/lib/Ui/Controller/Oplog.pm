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
      return $self->render(text=>'Ошибка соединения с управляющим сервером') unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>'Ошибка формата данных') unless $v;
        return $self->render(log_rec => $v);
      } else {
        if ($res->is_error) {
          return $self->render(text=>'Ошибка запроса: '.substr($res->body, 0, 60));
      }
        return $self->render(text=>'Неподдерживаемый ответ');
      }
    } # get closure
  );
}


1;
