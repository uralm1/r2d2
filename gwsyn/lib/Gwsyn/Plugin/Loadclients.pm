package Gwsyn::Plugin::Loadclients;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Mojo::UserAgent;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # 1.Recreate dhcphosts file, send SIGHUP to dnsmasq,
  # 2.
  # (blocking)
  # doesn't log anything to remote log, returns 1-success, croaks on error
  $app->helper(load_clients => sub {
    my $self = shift;

    my $res = eval {
      my $pid = $self->config('my_profile');
      my $tx = $self->ua->get($self->config('head_url')."/clients/$pid" => {Accept => 'application/json'});
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        if (my $v = $res->json) {
          # create dhcphosts file
          my $dhcpfile = path($self->config('dhcphosts_file'));
          my $fh = $dhcpfile->open('>');
          if (defined $fh) {
            # data
            for (@$v) {
              # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
              print $fh "$_->{mac},id:*,set:client$_->{id},$_->{ip}\n" if !$_->{no_dhcp} && $_->{mac};
            }
            $fh->close;

            # send SIGHUP to dnsmasq
            unless (eval { $self->sighup_dnsmasq }) {
              croak "can't SIGHUP dnsmasq: $@";
            }
            return 1;

          } else {
            croak "can't create dhcphosts file: $!";
          }
        } else {
          croak 'clients response json error';
        }
      } else {
        croak "clients request error: ".(($res->is_error) ? $res->body : '');
      }
    } else {
      croak "connection to head failed: $@";
    }
  });
}

1;
__END__
