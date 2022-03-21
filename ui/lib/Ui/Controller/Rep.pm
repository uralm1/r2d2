package Ui::Controller::Rep;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Mojo::Promise;

sub macdup {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render_later;

  $self->ua->get_p(Mojo::URL->new('/ui/rep/macdup')->to_abs($self->head_url) =>
    $self->accept_json)
  ->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);

    $self->render(res => $v);

  })->catch(sub {
    my $err = shift;
    if ($err) {
      $self->log->error($err);
      $self->render(text => 'Ошибка соединения с управляющим сервером');
    }# else { $self->log->debug('Skipped due empty reject') }
  });
}


sub ipmap {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render_later;

  $self->ua->get_p(Mojo::URL->new('/ui/rep/ipmap')->to_abs($self->head_url) =>
    $self->accept_json)
  ->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);

    #say $self->dumper($v);
    $self->render(ip_data => $v);

  })->catch(sub {
    my $err = shift;
    if ($err) {
      $self->log->error($err);
      $self->render(text => 'Ошибка соединения с управляющим сервером');
    }# else { $self->log->debug('Skipped due empty reject') }
  });
}


sub leechtop {
  my $self = shift;
  return undef unless $self->authorize({ admin=>1 });

  $self->render_later;

  $self->render(text => 'NOT IMPLEMENTED');
}


1;
