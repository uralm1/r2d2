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
    my $i = 1;
    # devices loop
    while (my $h = $results->hash) {
      my $mac = lc $h->{mac};
      my $ipo = NetAddr::IP::Lite->new($h->{ip}) || die 'IP address failure';
      my $ip = $ipo->addr;
      if ($mac eq q{} || $mac_hash{$mac} || $mac !~ /^$RE{net}{MAC}$/) {
        if ($i == 1) {
          push @res_tab, { %{ $mac_hash{$mac} } };
          $i++;
        }
        push @res_tab, { %$h, ip => $ip };
        $i++;
      } else {
        $mac_hash{$mac} = { %$h, ip => $ip };
        $i = 1;
      }
    }
    $self->render(json => \@res_tab);

  })->catch(sub {
    my $err = shift;

    $self->log->error($err);
    $self->render(text => 'Database error, macdup', status => 503);
  });
}


1;
