package Gwsyn::Plugin::Loadclients;
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
      my $pid = $self->config('my_profile');
      my $tx = $self->ua->get($app->config('head_url')."/clients/$pid" => {Accept => 'application/json'});
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        if (my $v = $res->json) {

            my $err;
            # part 1: firewall
            if (eval { $self->fwrules_create_full($v) }) {
              unless (eval { $self->fwrules_apply }) {
                $self->log->error("can't apply firewall changes: $@");
                $err = 11;
              }
            } else {
              $self->log->error("firewall file creation failed: $@");
              $err = 1;
            }

            # part 2: tc
            if (eval { $self->tcrules_create_full($v) }) {
              unless (eval { $self->tcrules_apply }) {
                $self->log->error("can't apply tc changes: $@");
                $err = 12;
              }
            } else {
              $self->log->error("tc file creation failed: $@");
              $err = 2;
            }

            # part 3: dhcp
            if (eval { $self->dhcp_create_full($v) }) {
              unless (eval { $self->dhcp_apply }) {
                $self->log->error("can't apply dhcp changes: $@");
                $err = 13;
              }
            } else {
              $self->log->error("dhcphosts file creation failed: $@");
              $err = 3;
            }
            die 'operation failed' if $err;
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
