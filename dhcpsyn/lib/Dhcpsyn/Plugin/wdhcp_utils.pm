package Dhcpsyn::Plugin::wdhcp_utils;
use Mojo::Base 'Mojolicious::Plugin';

use NetAddr::IP::Lite;
use NetAddr::MAC;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # {} = dhcp_matang;
  $app->helper(dhcp_matang => sub {
    my $self = shift;
    my $dhcpscope = $self->config('dhcpscope');
    return {
      'win_dhcp' => {
        dump_sub => sub {
          my $ds = shift; # dhcp_server_ip
          $self->system(netsh_dump => "dhcp server $ds scope $dhcpscope dump")
        },
        add_sub => sub {
          my ($ds, $ip, $bmac, $id) = @_; # dhcp_server_ip, ip, basic_mac, client_id
          $self->system(netsh => "dhcp server $ds scope $dhcpscope add reservedip $ip $bmac client$id client$id")
        },
        replace_sub => sub {},
        delete_sub => sub {
          my ($ds, $ip, $bmac) = @_; # dhcp_server_ip, ip, basic_mac
          $self->system(netsh => "dhcp server $ds scope $dhcpscope delete reservedip $ip $bmac")
        },
        zero_sub => sub {},
        # Dhcp Server 10.0.0.1 Scope 10.0.0.0 Add iprange 10.1.2.3 10.10.255.255 <- ignore this lines and others
        # Dhcp Server 10.0.0.1 Scope 10.0.0.0 Add reservedip 10.1.2.3 112233445566 "hostname.dom" "client1" "DHCP"
        # Dhcp Server \\10.0.0.1 Scope 10.0.0.0 Add reservedip 10.1.2.3 112233445566 "hostname.dom" "client2" "DHCP"
        re1 => sub {
          my ($ds, $id) = @_; # dhcp_server_ip, id
          # $1 - ip, $2 - mac
          qr/^dhcp\s+ server\s+ (?:\\\\)?\Q$ds\E\s+ scope\s+ \Q$dhcpscope\E\s+ add\s+ reservedip\s+ (\S+)\s+ (\S+)\s+ \S+\s+ "client\Q$id\E"\s+/ix
        },
        re2 => sub {
          my $ds = shift; # dhcp_server_ip
          # $1 - ip, $2 - mac, $3 - comment
          qr/^dhcp\s+ server\s+ (?:\\\\)?\Q$ds\E\s+ scope\s+ \Q$dhcpscope\E\s+ add\s+ reservedip\s+ (\S+)\s+ (\S+)\s+ \S+\s+ "(\S*)"\s+/ix
        },
        re_stat => sub {},
        rule_desc => 'Reservedip',
      },
    }
  });


  # my $resp = dhcp_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55:66'});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error
  #   will check ip/mac/no_dhcp flag and skip line if not set.
  $app->helper(dhcp_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $ipo = NetAddr::IP::Lite->new($v->{ip});
    die "Invalid ip address $v->{ip}, client $v->{id}!" unless $ipo;
    my $ip = $ipo->addr;
    my $bmac;
    if (!$v->{no_dhcp} && $v->{mac}) {
      my $maco = eval { NetAddr::MAC->new($v->{mac}) };
      die "Invalid mac address $v->{mac}, client $v->{id}!" if $@;
      $bmac = $maco->as_basic;
    }

    my $m = $self->dhcp_matang->{win_dhcp};
    croak "Matang win_dhcp matanga!" unless $m;

    my $failure = undef;

    for my $dhcpserver (@{$self->config('dhcpservers')}) {

      my $dump = $m->{dump_sub}($dhcpserver);
      unless ($dump) {
        $self->rlog($failure) if $failure;
        $failure = "failed DUMP dhcpserver $dhcpserver";
        next;
      }

      my $ff = 0;

      for (@$dump) {
        if ($_ =~ $m->{re1}($dhcpserver, $v->{id})) {
          if (!$ff) {
            if (!$v->{no_dhcp} && $v->{mac}) {
              $self->rlog("Replacing client id $v->{id} $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
              if ( $m->{delete_sub}($dhcpserver, $1, $2) ) {
                $self->rlog("Error deleting $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
              }
              if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $v->{id}) ) {
                $self->rlog($failure) if $failure;
                $failure = "failed ADD client id $v->{id} $m->{rule_desc} $ip mac $bmac on dhcp server $dhcpserver.";
              }
            } else {
              # delete reservedip if no_dhcp flag is set
              $self->rlog("Deleting client id $v->{id} $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
              if ( $m->{delete_sub}($dhcpserver, $1, $2) ) {
                $self->rlog($failure) if $failure;
                $failure = "failed DELETE $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.";
              }
            }
            $ff = 1;
          } else {
            $self->rlog("Deleting duplicate client id $v->{id} $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
            if ( $m->{delete_sub}($dhcpserver, $1, $2) ) {
              $self->rlog("Error deleting $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
            }
          }
        } # if regex
      } # for dump

      if (!$ff) { # if not found, add reservedip
        if (!$v->{no_dhcp} && $v->{mac}) {
          $self->rlog("Appending client id $v->{id} $m->{rule_desc} $ip mac $bmac on dhcp server $dhcpserver.");
          if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $v->{id}) ) {
            $self->rlog($failure) if $failure;
            $failure = "failed ADD client id $v->{id} $m->{rule_desc} $ip mac $bmac on dhcp server $dhcpserver.";
          }
        }
      }

    } # loop by dhcpservers

    die $failure if $failure;

    return 1;
  });


  # my $resp = dhcp_delete($id);
  # returns 1-deleted/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(dhcp_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $m = $self->dhcp_matang->{win_dhcp};
    croak "Matang win_dhcp matanga!" unless $m;

    my $failure = undef;
    my $ret = 0;
    for my $dhcpserver (@{$self->config('dhcpservers')}) {

      my $dump = $m->{dump_sub}($dhcpserver);
      unless ($dump) {
        $self->rlog($failure) if $failure;
        $failure = "failed DUMP dhcpserver $dhcpserver";
        next;
      }

      for (@$dump) {
        if ($_ =~ $m->{re1}($dhcpserver, $id)) {
          $self->rlog("Deleting client id $id $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.");
          $ret = 1;
          # delete
          if ( $m->{delete_sub}($dhcpserver, $1, $2) ) {
            $self->rlog($failure) if $failure;
            $failure = "failed DELETE $m->{rule_desc} $1 mac $2 on dhcp server $dhcpserver.";
          }
        }
      }

    } # loop by dhcpservers

    die $failure if $failure;

    return $ret;
  });

}

1;
