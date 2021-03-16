package Fwsyn::Plugin::Loadclients_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::UserAgent;

#use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # (blocking)
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
    die "clients request error: ".(($res->is_error) ? substr($res->body, 0, 40) : 'none') unless $res->is_success;

    my $v = $res->json;
    die 'clients response json error' unless $v;

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

    die join(',', @err) if @err;
    return 1; #success
  });
}


1;
