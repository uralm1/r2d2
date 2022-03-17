package Ui::Controller::Rep;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::URL;
use Mojo::Promise;

use Regexp::Common qw(net);

sub macdup {
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

    $self->stash(profiles_hash => $v);

    $self->ua->get_p(Mojo::URL->new('/devices')->to_abs($self->head_url) =>
      $self->accept_json);
  })->then(sub {
    my $tx = shift;
    my $res = $tx->result;
    return Mojo::Promise->reject unless $self->request_success($res);
    return Mojo::Promise->reject unless my $v = $self->request_json($res);
    return Mojo::Promise->reject('Invalid response format') if ref $v ne 'ARRAY';

    my @res_tab;
    my %mac_hash;
    my $i = 1;
    # devices loop
    for my $d (@$v) {
      my $mac = lc $d->{mac};
      if ($mac !~ /^$RE{net}{MAC}$/ || $mac_hash{$mac}) {
        if ($i == 1) {
          push @res_tab, {mac => $mac, %{$mac_hash{$mac}}};
          $i++;
        }
        push @res_tab, {mac => $mac, ip => $d->{ip}, no_dhcp => $d->{no_dhcp}, profile => $d->{profile}};
        $i++;
      } else {
        $mac_hash{$mac} = {ip => $d->{ip}, no_dhcp => $d->{no_dhcp}, profile => $d->{profile}};
      }
    } # for devices

    $self->render(res_tab => \@res_tab);

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


1;
