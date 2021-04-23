package Rtsyn::Plugin::Loadclients_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::UserAgent;

#use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # build rulefile and load it to iptables (blocking)
  # doesn't log anything to remote log, returns 1-success, dies on error
  $app->helper(load_clients => sub {
    my $self = shift;

    my $profs = $self->config('my_profiles');
    my $res = eval {
      my $tx = $self->ua->get(Mojo::URL->new('/clients')->to_abs($self->head_url)
        ->query(profile => $profs) => {Accept => 'application/json'});
      $tx->result;
    };
    die "connection to head failed: $@" unless defined $res;
    die "clients request error: ".(($res->is_error) ? substr($res->body, 0, 40) : 'none')."\n" unless $res->is_success;

    my $v = $res->json;
    die "clients response json error\n" unless $v;

    my @err;
    if (my $r = eval { $self->rt_create_full($v) }) {
      push @err, "Error applying firewall changes: $@" unless eval { $self->rt_apply };
    } elsif (!defined $r) {
      push @err, "Firewall file creation failed: $@";
    }

    die join(',', @err) if @err;
    return 1; # success
  });
}


1;
