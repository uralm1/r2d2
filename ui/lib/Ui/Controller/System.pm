package Ui::Controller::System;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::Promise;


sub index {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  my $active_page = $self->param('p') || 1;
  return unless $self->exists_and_number($active_page);

  $self->render_later;

  # perform sequentially
  $self->ua->get_p(Mojo::URL->new('/subsys')->to_abs($self->head_url) =>
    {Accept => 'application/json'}
  )->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);
    my $head_status = $v->{subsys} ? "OK: $v->{subsys}" : 'НЕВЕРНЫЕ ДАННЫЕ';
    $head_status .= " ($v->{version})" if defined $v->{version};
    $self->stash(head_status => $head_status,
      db => $v->{db}, 'db-minion' => $v->{'db-minion'});

    $self->ua->get_p(Mojo::URL->new('/ui/profiles/status')->to_abs($self->head_url)->
      query({page => $active_page, lop => $self->config('lines_on_page')}) =>
      {Accept => 'application/json'});
  })->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);
    $self->stash(profiles_status => $v);

    $self->ua->get_p(Mojo::URL->new('/ui/syncqueue/status')->to_abs($self->head_url) =>
      {Accept => 'application/json'});
  })->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return unless $self->request_success($res);
    return unless my $v = $self->request_json($res);

    # stash: head_status, profiles_status
    $self->render(sync_queue => $v);

  })->catch(sub {
    my $err = shift;
    if ($err) {
      $self->log->error($err);
      $self->render(text => 'Ошибка соединения с управляющим сервером');
    }# else { $self->log->debug('Skipped due empty reject') }
  });
}


1;
