package Gwsyn::Plugin::Loadclients_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Mojo::UserAgent;

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
      my $tx = $self->ua->get($app->config('head_url')."/clients/$prof" => {Accept => 'application/json'});
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        if (my $v = $res->json) {

            my @err;
            # part 1: firewall
            if (my $r = eval { $self->fw_create_full($v) }) {
              push @err, "Error applying firewall changes: $@" unless eval { $self->fw_apply };
            } elsif (!defined $r) {
              push @err, "Firewall file creation failed: $@";
            }

            # part 2: tc
            if (my $r = eval { $self->tc_create_full($v) }) {
              push @err, "Error applying tc changes: $@" unless eval { $self->tc_apply };
            } elsif (!defined $r) {
              push @err, "Tc file creation failed: $@";
            }

            # part 3: dhcp
            if (my $r = eval { $self->dhcp_create_full($v) }) {
              push @err, "Error applying dhcp changes: $@" unless eval { $self->dhcp_apply };
            } elsif (!defined $r) {
              push @err, "Dhcphosts file creation failed: $@";
            }

            die join(',', @err) if @err;
            return 1; #success

        } else {
          die 'clients response json error';
        }
      } else {
        die "clients request error: ".(($res->is_error) ? $res->body : '');
      }
    } else {
      die "connection to head failed: $@";
    }
  });
}


1;
