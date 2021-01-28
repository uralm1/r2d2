package Dhcpsyn::Plugin::Loadclients_impl;
use Mojo::Base 'Mojolicious::Plugin';

use NetAddr::IP::Lite;
use NetAddr::MAC;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # (blocking)
  # doesn't log anything to remote log, returns 1-success, dies on error
  $app->helper(load_clients => sub {
    my $self = shift;

    my $prof = $self->config('my_profile');
    my $res = eval {
      my $tx = $self->ua->get($self->config('head_url')."/clients/$prof" => {Accept => 'application/json'});
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        if (my $v = $res->json) {

          for my $dhcpserver (@{$self->config('dhcpservers')}) {

            my $m = $self->dhcp_matang->{win_dhcp};
            croak "Matang win_dhcp matanga!" unless $m;

            # get dump and parse
            my $dump = $m->{dump_sub}($dhcpserver);
            die "Error dumping reservedip dhcpserver: $dhcpserver" unless $dump;

            my %reservations;
            for (@$dump) {
              if ($_ =~ $m->{re_dump}($dhcpserver)) {
                $self->log->warn("Duplicate ip $1 in dhcpserver: $dhcpserver dump") if exists $reservations{$1};
                $reservations{$1} = $2;
              }
            }

            # process data
            for (@$v) {
              next if (!$_->{profile} or $_->{profile} ne $prof); # skip clients from invalid profiles
              if (!$_->{no_dhcp} && $_->{mac}) {
                my $ipo = NetAddr::IP::Lite->new($_->{ip});
                unless ($ipo) {
                  $self->rlog("Invalid ip address $_->{ip}, client $_->{id} ignored!");
                  next;
                }
                my $ip = $ipo->addr;
                my $maco = eval { NetAddr::MAC->new($_->{mac}) };
                if ($@) {
                  $self->rlog("Invalid mac address $_->{mac}, client $_->{id} ignored!");
                  next;
                }
                my $bmac = $maco->as_basic;

                if (my $old_bmac = $reservations{$ip}) {
                  if ($old_bmac ne $bmac) {
                    # delete
                    if ( $m->{delete_sub}($dhcpserver, $ip, $old_bmac) ) {
                      $self->rlog("Error deleting old reservedip $ip mac $old_bmac on dhcp server $dhcpserver.");
                    }
                    # add
                    if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $_->{id}) ) {
                      $self->rlog("Error adding new reservedip $ip mac $bmac on dhcp server $dhcpserver.");
                    }
                  }
                } else {
                  # add
                  if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $_->{id}) ) {
                    $self->rlog("Error adding new reservedip $ip mac $bmac on dhcp server $dhcpserver.");
                  }
                }
              }
            } # clients json loop

          } # loop by dhcpservers

        } else {
          die 'clients response json error';
        }
      } else {
        die "clients request error: ".(($res->is_error) ? substr($res->body, 0, 40) : '');
      }
    } else {
      die "connection to head failed: $@";
    }
  });
}


1;
