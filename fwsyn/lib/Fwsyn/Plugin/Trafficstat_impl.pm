package Fwsyn::Plugin::Trafficstat_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::UserAgent;

#use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # doesn't log anything to remote log, returns 1-success, dies on error
  $app->helper(traffic_stat => sub {
    my $self = shift;

    my $matang = $self->fw_matang;
    my %buf;

    for my $n (qw/in out/) {
      my $m = $matang->{"f_$n"};
      $self->rlog("Processing traffic stat $m->{rule_desc}.");
      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table\n" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re_stat}()) {
          #$self->log->debug("rule $1 $n $2 ip $3 id $4");
          $buf{$4}{$n} = $2 if defined($2) and defined($4) and $2 > 0;
        }
      } # for dump
    }

    for (keys %buf) { # ensure both in/out elements exist
      $buf{$_}{in} //= 0;
      $buf{$_}{out} //= 0;
    }

    # NOW SEND
    my $profs = $self->config('my_profiles');
    my $res = eval {
      my $tx = $self->ua->post(Mojo::URL->new('/trafstat')->to_abs($self->head_url)
        ->query(profile => $profs) => json => \%buf);
      $tx->result;
    };
    die "Stats submit to head failed: $@" unless defined $res;
    die 'Stats submit request error: '.($res->is_error ? substr($res->body, 0, 40) : 'none')."\n" unless $res->is_success;

    $self->rlog('Traffic stat submitted: '.substr($res->body, 0, 20).'. Resetting rule counters.');
    for (qw/f_in f_out/) {
      my $m = $matang->{$_};
      if ($m->{zero_sub}()) {
        $self->rlog("Stat $m->{rule_desc}. Can't reset counters.");
      }
    }

    return 1;
  });
}


1;
