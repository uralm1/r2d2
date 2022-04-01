package Head::Controller::UiRep;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;
use Mojo::Promise;

use NetAddr::IP::Lite;
use Regexp::Common qw(net);
use Head::Ural::Profiles;


sub ipmap {
  my $self = shift;

  $self->render_later;

  my $db = $self->mysql_inet->db;
  my $ip_data = [];

  $self->profiles->hash_p
  ->then(sub {
    my $ph = shift;
    for (sort keys %$ph) {
      push @$ip_data, { profile => $_, profile_name => $ph->{$_}, total_addr => 0 };
    }

    Mojo::Promise->map({concurrency => 1}, sub {
      $db->query_p("SELECT id, ip FROM devices WHERE profile = ? ORDER BY id ASC",
        $_->{profile}
      );
    }, @$ip_data);

  })->then(sub {
    for (@$ip_data) {
      if (my $item = shift @_) {
        my $ips = {};
        while (my $dev = $item->[0]->array) {
          my $ipo = NetAddr::IP::Lite->new($dev->[1]) || die 'IP address failure';
          my $ip = $ipo->addr;
          # split ip
          if ($ip =~ /^$RE{net}{IPv4}{-keep}$/) {
            #push @$ips, $ip;
            if (defined $2 && defined $3 && defined $4 && defined $5) {
              push @{$ips->{$2}->{$3}->{$4}}, {b => $5, id => $dev->[0]};
            } else {
              $self->log->error("IP address: $ip was ignored due bad parsing");
            }

          } else {
            $self->log->error("IP address: $ip was ignored due invalid format");
          }
          $_->{total_addr}++;
        }
        $_->{ips} = $ips;
      }
    }
    $self->render(json => $ip_data);

  })->catch(sub {
    my $err = shift;

    $self->log->error($err);
    $self->render(text => "Database error, ipmap", status => 503);
  });
}


sub macdup {
  my $self = shift;

  $self->render_later;

  $self->mysql_inet->db->query_p("SELECT d.id, d.name, ip, mac, no_dhcp, d.profile, p.name AS profile_name, \
d.client_id AS client_id, c.cn AS client_cn \
FROM devices d \
INNER JOIN clients c ON d.client_id = c.id \
LEFT OUTER JOIN profiles p ON d.profile = p.profile \
ORDER BY d.id ASC LIMIT 1000")
  ->then(sub {
    my $results = shift;

    my @res_tab;
    my %mac_hash;
    # devices loop
    while (my $h = $results->hash) {
      my $mac = lc $h->{mac};
      my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
      my $ip = $ipo->addr;
      if ($mac eq q{} || $mac_hash{$mac} || $mac !~ /^$RE{net}{MAC}$/) {
        unless ($mac_hash{$mac}{printed}) {
          push @res_tab, { %{ $mac_hash{$mac} } };
          $mac_hash{$mac}{printed} = 1;
        }
        push @res_tab, { %$h, ip => $ip };
      } else {
        $mac_hash{$mac} = { %$h, ip => $ip };
      }
    }
    $self->render(json => \@res_tab);

  })->catch(sub {
    my $err = shift;

    $self->log->error($err);
    $self->render(text => 'Database error, macdup', status => 503);
  });
}


sub monthtop {
  my $self = shift;
  my $prev = $self->param('prev') // 0;
  my $count = $self->param('count') // 15;
  return $self->render(text => 'Bad count parameter', status => 400)
    if $count !~ /^\d+$/ || $count < 1 || $count > 100;

  $self->render_later;

  if ($prev eq q{0}) {
    $self->_get_cur_month_data($count);
  } elsif ($prev eq q{1}) {
    $self->_get_prev_month_data($count);
  } else {
    $self->render(text => 'Bad parameter format', status => 400);
  }
}


sub _get_cur_month_data {
  my ($self, $count) = @_;

  my $db = $self->mysql_inet->db;
  $db->query_p("SELECT d.id, c.id AS client_id, c.cn AS client_cn, \
MAX(IF(CAST(sum_in AS SIGNED)-CAST(m_in AS SIGNED) >= 0, CAST(sum_in AS SIGNED)-CAST(m_in AS SIGNED), sum_in)) AS r_in, \
MAX(IF(CAST(sum_out AS SIGNED)-CAST(m_out AS SIGNED) >= 0, CAST(sum_out AS SIGNED)-CAST(m_out AS SIGNED), sum_out)) AS r_out \
FROM devices d \
INNER JOIN amonthly m ON m.device_id = d.id \
AND m.date <= CURDATE() AND m.date >= SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)) \
INNER JOIN clients c ON d.client_id = c.id \
GROUP BY d.id, c.id, c.cn \
ORDER BY d.id")
  ->then(sub {
    my $results = shift;
    my %dh;

    while (my $n = $results->hash) {
      my $client_id = $n->{client_id};

      if ($dh{$client_id}) {
        $dh{$client_id}[1] += $n->{r_in};
        $dh{$client_id}[2] += $n->{r_out};
      } else {
        $dh{$client_id} = [
          $n->{client_cn}, #0 client_cn
          $n->{r_in}, #1 in
          $n->{r_out}, #2 out
          $n->{client_id}, #3 client_id
        ];
      }
    }

    my @sl = sort { $b->[1] <=> $a->[1] } values %dh;
    my @l;
    my $i = 0;
    my ($other_in, $other_out) = (0, 0);
    for (@sl) {
      if ($i < $count) {
        push @l, { client => $_->[0], in => $_->[1], out => $_->[2], id => $_->[3] };
      } else {
        $other_in += $_->[1];
        $other_out += $_->[2];
      }
      $i++;
    }
    push @l, { client => 'Остальные', in => $other_in, out => $other_out };

    $self->render(json => \@l);

  })->catch(sub {
    my $err = shift;

    $self->log->error($err);
    $self->render(text => 'Database error, monthtop (current month)', status => 503);
  });
}


sub _get_prev_month_data {
  my ($self, $count) = @_;

  my $db = $self->mysql_inet->db;
  $db->query_p("SELECT d.id, c.id AS client_id, c.cn AS client_cn, \
MAX(CAST(m_in AS SIGNED)) - MIN(CAST(m_in AS SIGNED)) AS r_in, \
MAX(CAST(m_out AS SIGNED)) - MIN(CAST(m_out AS SIGNED)) AS r_out \
FROM devices d \
INNER JOIN amonthly m ON m.device_id = d.id \
AND m.date <= SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)) \
AND m.date >= SUBDATE(SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)), INTERVAL 1 MONTH) \
INNER JOIN clients c ON d.client_id = c.id \
GROUP BY d.id, c.id, c.cn \
ORDER BY d.id")
  ->then(sub {
    my $results = shift;
    my %dh;

    while (my $n = $results->hash) {
      my $client_id = $n->{client_id};

      if ($dh{$client_id}) {
        $dh{$client_id}[1] += $n->{r_in};
        $dh{$client_id}[2] += $n->{r_out};
      } else {
        $dh{$client_id} = [
          $n->{client_cn}, #0 client_cn
          $n->{r_in}, #1 in
          $n->{r_out}, #2 out
          $n->{client_id}, #3 client_id
        ];
      }
    }

    my @sl = sort { $b->[1] <=> $a->[1] } values %dh;
    my @l;
    my $i = 0;
    my ($other_in, $other_out) = (0, 0);
    for (@sl) {
      if ($i < $count) {
        push @l, { client => $_->[0], in => $_->[1], out => $_->[2], id => $_->[3] };
      } else {
        $other_in += $_->[1];
        $other_out += $_->[2];
      }
      $i++;
    }
    push @l, { client => 'Остальные', in => $other_in, out => $other_out };

    $self->render(json => \@l);

  })->catch(sub {
    my $err = shift;

    $self->log->error($err);
    $self->render(text => 'Database error, monthtop (previous month)', status => 503);
  });
}


1;

=for comment
  # current month, first variant
  my @datalist;

  my $results = $db->query("SELECT d.id, ip, sum_in, sum_out, d.client_id AS client_id, c.cn AS client_cn \
FROM devices d \
INNER JOIN clients c ON d.client_id = c.id \
ORDER BY d.id ASC");
  while (my $n = $results->hash) {
    my $ipo = NetAddr::IP::Lite->new($n->{ip});
    my $sum_in = $n->{sum_in};
    my $sum_out = $n->{sum_out};

    my $result2 = $db->query("SELECT m_in, m_out FROM amonthly WHERE device_id = ? \
AND date <= CURDATE() AND date >= SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)) \
ORDER BY date ASC", $n->{id});
    if (my $n2 = $result2->hash) {
      my $r_in = $sum_in - $n2->{m_in};
      $r_in = $sum_in if $r_in < 0;
      my $r_out = $sum_out - $n2->{m_out};
      $r_out = $sum_out if $r_out < 0;
      push @datalist,
        { id => $n->{id},
          ip => $ipo->addr,
          in => $r_in,
          out => $r_out,
          client_id => $n->{client_id},
          client_cn => $n->{client_cn}
        };
    }
  }

  # current month, second variant
  my @datalist;

  my $results = $db->query("SELECT d.id, c.id AS client_id, c.cn AS client_cn, \
MAX(IF(CAST(sum_in AS SIGNED)-CAST(m_in AS SIGNED) >= 0, CAST(sum_in AS SIGNED)-CAST(m_in AS SIGNED), sum_in)) AS r_in, \
MAX(IF(CAST(sum_out AS SIGNED)-CAST(m_out AS SIGNED) >= 0, CAST(sum_out AS SIGNED)-CAST(m_out AS SIGNED), sum_out)) AS r_out \
FROM devices d \
INNER JOIN amonthly m ON m.device_id = d.id \
AND m.date <= CURDATE() AND m.date >= SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)) \
INNER JOIN clients c ON d.client_id = c.id \
GROUP BY d.id, c.id, c.cn \
ORDER BY d.id");
  while (my $n = $results->hash) {
    push @datalist,
      { id => $n->{id},
        in => $n->{r_in},
        out => $n->{r_out},
        client_id => $n->{client_id},
        client_cn => $n->{client_cn}
      };
  }

  # previous month, first variant
  my @datalist;

  my $results = $db->query("SELECT d.id, ip, d.client_id AS client_id, c.cn AS client_cn \
FROM devices d \
INNER JOIN clients c ON d.client_id = c.id \
ORDER BY d.id ASC");
  while (my $n = $results->hash) {
    my $ipo = NetAddr::IP::Lite->new($n->{ip});

    my $results2 = $db->query("SELECT m_in, m_out FROM amonthly WHERE device_id = ? \
AND date <= SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)) \
AND date >= SUBDATE(SUBDATE(CURDATE(), (DAY(CURDATE()) - 1)), INTERVAL 1 MONTH) \
ORDER BY date DESC", $n->{id});
    my ($m_in, $m_out);
    my ($r_in, $r_out);
    my $rr = $results2->rows;
    if (my $n2 = $results2->hash) {
      $r_in = $n2->{m_in};
      $r_out = $n2->{m_out};
      while (my $n3 = $results2->hash) { # skip records
        $m_in = $n3->{m_in};
        $m_out = $n3->{m_out};
      }
      if ($rr > 1) {
        $r_in -= $m_in if $r_in >= $m_in;
        $r_out -= $m_out if $r_out >= $m_out;
      }
      push @datalist,
        { id => $n->{id},
          ip => $ipo->addr,
          in => $r_in,
          out => $r_out,
          client_id => $n->{client_id},
          client_cn => $n->{client_cn}
        };
    }
  }

=cut
