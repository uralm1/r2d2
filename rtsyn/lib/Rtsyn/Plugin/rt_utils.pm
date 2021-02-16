package Rtsyn::Plugin::rt_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $txt = $app->rt_marks($rt)
  $app->helper(rt_marks => sub {
    my ($self, $rt) = @_;

    state %rt_marks = (
      0 => '', # ufanet
      1 => '-j MARK --set-mark 2', # beeline
    );

    return $rt_marks{$rt};
  });


  # {} = rt_matang;
  $app->helper(rt_matang => sub {
    my $self = shift;
    my $client_out_chain = $self->config('client_out_chain');
    return {
      'm_out' => {
        table => 'mangle',
        chain => $client_out_chain,
        dump_sub => sub { $self->system(iptables_dump => "-t mangle -nvx --line-numbers -L $client_out_chain") },
        add_sub => sub {
          my $v = shift; # {id=>1, etc}
          $self->system(iptables => "-t mangle -A $client_out_chain -s $v->{ip} -m comment --comment $v->{id} ".$self->rt_marks($v->{rt}))
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id} ".$self->rt_marks($v->{rt}))
        },
        delete_sub => sub {
          my $ri = shift; # rule index
          $self->system(iptables => "-t mangle -D $client_out_chain $ri")
        },
        zero_sub => sub {},
        # n pkt bytes MARK all -- * * 10.15.0.2 0.0.0.0/0 /* id */ MARK set 0x2
        # n pkt bytes      all -- * * 10.15.0.2 0.0.0.0/0 /* id */
        re1 => sub {
          my $id = shift;
          # $1 - n, $2 - ip
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {},
        rule_desc => 'Marking-rules',
      },
    }
  });


  # my $resp = rt_add_replace({id=>11, ip=>'1.2.3.4', rt=>0});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error
  $app->helper(rt_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $m = $self->rt_matang->{m_out};
    croak "Matang m_out matanga!" unless $m;

    my $ff = 0;
    my $failure = undef;

    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

    for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
      if ($dump->[$i] =~ $m->{re1}($v->{id})) {
        my $ri = $1;
        if (!$ff) {
          $self->rlog("$m->{rule_desc} sync. Replacing rule #$ri client id $v->{id} ip $2 in $m->{table} table.");
          $ff = 1;
          if ( $m->{replace_sub}($ri, $v) ) {
            $failure = "$m->{rule_desc} sync error. Can't replace rule #$ri in $m->{table} table.";
          }
        } else {
          $self->rlog("$m->{rule_desc} sync. Deleting duplicate rule #$ri client id $v->{id} ip $2 in $m->{table} table.");
          if ( $m->{delete_sub}($ri) ) {
            # just warn, count it non-fatal
            $self->rlog("$m->{rule_desc} sync error. Can't delete rule #$ri from $m->{table} table.");
          }
        }
      } # if regex
    } # for dump

    if (!$ff) { # if not found, add rule
      $self->rlog("$m->{rule_desc} sync. Appending rule client id $v->{id} ip $v->{ip} to $m->{table} table.");
      if ( !$m->{add_sub}($v) ) {
        # successfully added
        return 1;

      } else {
        $failure = "$m->{rule_desc} sync error. Can't append rule id $v->{id} to $m->{table} table.";
      }
    }

    die $failure if $failure;

    # successfully replaced
    return 1;
  });


  # my $resp = rt_delete($id);
  # returns 1-deleted/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(rt_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $m = $self->rt_matang->{m_out};
    croak "Matang m_out matanga!" unless $m;
    my $ret = 0;
    my $failure = undef;

    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

    for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
      if ($dump->[$i] =~ $m->{re1}($id)) {
        my $ri = $1;
        $self->rlog("$m->{rule_desc} sync. Rule #$ri client id $id ip $2 has been requested to delete. Deleting.");
        $ret = 1;
        if ( $m->{delete_sub}($ri) ) {
          my $msg = "$m->{rule_desc} sync error. Can't delete rule from $m->{table} table.";
          if ($failure) {
            $self->rlog($msg); # count not first errors non-fatal
          } else {
            $failure = $msg;
          }
        }
      } # if regex
    } # for dump

    die $failure if $failure;

    return $ret;
  });

}

1;
