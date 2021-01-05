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

    my $res = eval {
      my $prof = $self->config('my_profile');
      my $tx = $self->ua->get($app->config('head_url')."/clients/$prof" => {Accept => 'application/json'});
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        if (my $v = $res->json) {

            my $err;
            # part 1: firewall
            if (eval { $self->fwrules_create_full($v) }) {
              unless (eval { $self->fwrules_apply }) {
                $err = "can't apply firewall changes: $@";
              }
            } else {
              $err = "firewall file creation failed: $@";
            }

            # part 2: tc
            if (eval { $self->tcrules_create_full($v) }) {
              unless (eval { $self->tcrules_apply }) {
                $err = "can't apply tc changes: $@";
              }
            } else {
              $err = "tc file creation failed: $@";
            }

            # part 3: dhcp
            if (eval { $self->dhcp_create_full($v) }) {
              unless (eval { $self->dhcp_apply }) {
                $err = "can't apply dhcp changes: $@";
              }
            } else {
              $err = "dhcphosts file creation failed: $@";
            }
            die 'operation failed - $err' if $err;
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
