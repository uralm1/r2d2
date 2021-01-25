package Gwsyn::Plugin::Trafficstat_impl;
use Mojo::Base 'Mojolicious::Plugin';

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
      die "Error dumping rules $m->{chain} in $m->{table} table" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re_stat}()) {
          $self->log->info("rule $1 $n $2 ip $3 id $4");
          $buf{$4}{$n} = $2 if defined($2) and defined($4) and $2 > 0;
        }
      } # for dump
    }

    for (keys %buf) { # ensure both in/out elements exist
      $buf{$_}{in} //= 0;
      $buf{$_}{out} //= 0;
    }

    # NOW SEND
    my $prof = $self->config('my_profile');
    my $res = eval {
      my $tx = $self->ua->post($self->config('head_url')."/trafstat/$prof" => json => \%buf);
      $tx->result;
    };
    if (defined $res) {
      if ($res->is_success) {
        $self->rlog('Traffic stat submitted: '.substr($res->body, 0, 20).'. Resetting rule counters.');
        for (qw/f_in f_out/) {
          my $m = $matang->{$_};
          if ($m->{zero_sub}()) {
            $self->rlog("Stat $m->{rule_desc}. Can't reset counters.");
          }
        }

      } else {
        die 'Stats submit request error: '.($res->is_error ? substr($res->body, 0, 40) : '');
      }
    } else {
      die "Stats submit to head failed: $@";
    }

    return 1;
  });
}


1;
