package Gwsyn::Plugin::Loadclients;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Mojo::UserAgent;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # 1.Build dhcphosts file, then send SIGHUP to dnsmasq,
  # 2.
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

            # FIXME exception processing
            eval { $self->fwrules_create_full($v) } or die "firewall file creation failed: $@";
            eval { $self->tcrules_create_full($v) } or die "tc file creation failed: $@";

            eval { $self->dhcp_create_full($v) } or die "dhcphosts file creation failed: $@";
            eval { $self->dhcp_apply } or die "can't apply dhcp changes: $@";

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
