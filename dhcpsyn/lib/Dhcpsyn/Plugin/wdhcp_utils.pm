package Dhcpsyn::Plugin::wdhcp_utils;
use Mojo::Base 'Mojolicious::Plugin';

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
          $self->system(netsh => "dhcp server $ds scope $dhcpscope add reservedip $ip $bmac client$id")
        },
        replace_sub => sub {
          #my ($ri, $v) = @_; # rule index, {id=>1, etc}
          #$self->system(iptables => "-t mangle -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id} ".$self->rt_marks($v->{rt}))
        },
        delete_sub => sub {
          my ($ds, $ip, $bmac) = @_; # dhcp_server_ip, ip, basic_mac
          $self->system(netsh => "dhcp server $ds scope $dhcpscope delete reservedip $ip $bmac")
        },
        zero_sub => sub {},
        # Dhcp Server 10.0.0.1 Scope 10.0.0.0 Add iprange 10.1.2.3 10.10.255.255 <- ignore this lines and others
        # Dhcp Server 10.0.0.1 Scope 10.0.0.0 Add reservedip 10.1.2.3 112233445566 "hostname.dom" "" "DHCP"
        # Dhcp Server \\10.0.0.1 Scope 10.0.0.0 Add reservedip 10.1.2.3 112233445566 "hostname.dom" "" "DHCP"
        re_dump => sub {
          my $ds = shift; # dhcp_server_ip
          qr/^dhcp\s+ server\s+ (?:\\\\)?\Q$ds\E\s+ scope\s+ \Q$dhcpscope\E\s+ add\s+ reservedip\s+ (\S+)\s+ (\S+)\s+/ix
        },
        re_stat => sub {},
        rule_desc => 'Reservedip-list',
      },
    }
  });

=for comment
  # my $resp = rt_add_replace({id=>11, ip=>'1.2.3.4', rt=>0});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error
  $app->helper(rt_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $m = $self->rt_matang->{m_out};
    croak "Matang m_out matanga!" unless $m;

    my $ff = 0;
    my $failure = undef;

    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

    for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
      if ($dump->[$i] =~ $m->{re1}($v->{id})) {
        my $ri = $1;
        if (!$ff) {
          $self->rlog("$m->{rule_desc} sync. Replacing rule #$ri id $v->{id} ip $2 in $m->{table} table.");
          $ff = 1;
          if ( $m->{replace_sub}($ri, $v) ) {
            $failure = "$m->{rule_desc} sync error. Can't replace rule #$ri in $m->{table} table.";
          }
        } else {
          $self->rlog("$m->{rule_desc} sync. Deleting duplicate rule #$ri id $v->{id} ip $2 in $m->{table} table.");
          if ( $m->{delete_sub}($ri) ) {
            # just warn, count it non-fatal
            $self->rlog("$m->{rule_desc} sync error. Can't delete rule #$ri from $m->{table} table.");
          }
        }
      } # if regex
    } # for dump

    if (!$ff) { # if not found, add rule
      $self->rlog("$m->{rule_desc} sync. Appending rule id $v->{id} ip $v->{ip} to $m->{table} table.");
      if ( !$m->{add_sub}($v) ) {
        # successfully added
        return 1;

      } else {
        $failure = "$m->{rule_desc} sync error. Can't append rule id $v->{id} to $m->{table} table.";
      }
    }

    die $failure if $failure;

    # successfully replaced
    return 1;
  });


  # my $resp = rt_delete($id);
  # returns 1-deleted/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(rt_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $m = $self->rt_matang->{m_out};
    croak "Matang m_out matanga!" unless $m;
    my $ret = 0;
    my $failure = undef;

    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

    for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
      if ($dump->[$i] =~ $m->{re1}($id)) {
        my $ri = $1;
        $self->rlog("$m->{rule_desc} sync. Rule #$ri id $id ip $2 has been requested to delete. Deleting.");
        $ret = 1;
        if ( $m->{delete_sub}($ri) ) {
          my $msg = "$m->{rule_desc} sync error. Can't delete rule from $m->{table} table.";
          if ($failure) {
            $self->rlog($msg); # count not first errors non-fatal
          } else {
            $failure = $msg;
          }
        }
      } # if regex
    } # for dump

    die $failure if $failure;

    return $ret;
  });
=cut
}

1;
