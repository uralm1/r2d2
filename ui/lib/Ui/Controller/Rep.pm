package Ui::Controller::Rep;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Mojo::Promise;

use Regexp::Common qw(net);

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

  $self->ua->get_p(Mojo::URL->new('/ui/profiles')->to_abs($self->head_url) =>
    $self->accept_json)
  ->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);
    return Mojo::Promise->reject('Invalid response format') if ref $v ne 'HASH';

    my $ip_data = [];
    for (sort keys %$v) {
      push @$ip_data, { profile => $_, profile_name => $v->{$_}, total_addr => 0 };
    }
    $self->stash(ip_data => $ip_data);

    Mojo::Promise->map({concurrency => 1}, sub {
      $self->ua->get_p(Mojo::URL->new('/devices')->to_abs($self->head_url) ->
        query({profile => $_->{profile}}) =>
        $self->accept_json
      );
    }, @$ip_data);

  })->then(sub {
    my $ip_data = $self->stash('ip_data');

    for (@$ip_data) {
      if (my $item = shift @_) {
        my $tx = $item->[0];
        my $res = $tx->result;
        return Mojo::Promise->reject unless $self->request_success($res);
        return Mojo::Promise->reject unless my $v = $self->request_json($res);
        return Mojo::Promise->reject('Invalid response format') if ref $v ne 'ARRAY';

        my $ips = {};
        for my $dev (@$v) {
          if ($dev->{profile} eq $_->{profile}) {
            # split ip
            if ($dev->{ip} =~ /^$RE{net}{IPv4}{-keep}$/) {
              #push @$ips, $dev->{ip};
              if (defined $2 && defined $3 && defined $4 && defined $5) {
                push @{$ips->{$2}->{$3}->{$4}}, {b => $5, id => $dev->{id}};
              } else {
                $self->log->error("IP address: $dev->{ip} was ignored due bad parsing");
              }

            } else {
              $self->log->error("IP address: $dev->{ip} was ignored due invalid format");
            }
            $_->{total_addr}++;

          } else {
            $self->log->error("IP address: $dev->{ip} was ignored due invalid profile");
          }
        }
        $_->{ips} = $ips;
      }
    }
    #say $self->dumper($ip_data);
    $self->render;

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
