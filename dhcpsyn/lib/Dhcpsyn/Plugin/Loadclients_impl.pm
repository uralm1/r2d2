package Dhcpsyn::Plugin::Loadclients_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
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

    my $prof = ${ $self->config('my_profiles') }[0]; #FIXME
    my $res = eval {
      my $tx = $self->ua->get(Mojo::URL->new("/clients/$prof")->to_abs($self->head_url) => {Accept => 'application/json'});
      $tx->result;
    };

    die "connection to head failed: $@" unless defined $res;
    die "clients request error: ".(($res->is_error) ? substr($res->body, 0, 40) : 'none') unless $res->is_success;
    my $v = $res->json;
    die 'clients response json error' unless $v;

    my $m = $self->dhcp_matang->{win_dhcp};
    croak "Matang win_dhcp matanga!" unless $m;

    my $failure = undef;

    for my $dhcpserver (@{$self->config('dhcpservers')}) {

      # get dump and parse
      my $dump = $m->{dump_sub}($dhcpserver);
      unless ($dump) {
        $self->rlog($failure) if $failure;
        $failure = "dump failed dhcpserver $dhcpserver";
        next;
      }

      my %reservations;
      for (@$dump) {
        if ($_ =~ $m->{re2}($dhcpserver)) {
          $self->log->warn("Duplicate ip $1 in dhcpserver: $dhcpserver dump") if exists $reservations{$1};
          $reservations{$1} = {mac => $2, comment=> $3};
        }
      }

      # process data
      for (@$v) {
        next if !$self->is_myprofile($_->{profile}); # skip clients from invalid profiles
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

          if (my $rh = $reservations{$ip}) {
            if ($bmac ne $rh->{mac} || $rh->{comment} !~ /^client\Q$_->{id}\E$/) {
              # delete
              if ( $m->{delete_sub}($dhcpserver, $ip, $rh->{mac}) ) {
                $self->rlog("Error deleting old reservedip $ip mac $rh->{mac} on dhcp server $dhcpserver.");
              }
              # add
              if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $_->{id}) ) {
                $self->rlog("Error adding client $_->{id} new reservedip $ip mac $bmac on dhcp server $dhcpserver.");
              }
            }
          } else {
            # add
            if ( $m->{add_sub}($dhcpserver, $ip, $bmac, $_->{id}) ) {
              $self->rlog("Error adding client $_->{id} new reservedip $ip mac $bmac on dhcp server $dhcpserver.");
            }
          }
        }
      } # clients json loop

    } # loop by dhcpservers

    die $failure if $failure;

    return 1;
  });
}


1;
