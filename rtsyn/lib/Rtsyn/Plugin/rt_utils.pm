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


  # [iptables_dump_lines] = rt_dump;
  # returns undef on error.
  $app->helper(rt_dump => sub {
    my $self = shift;
    return $self->system(iptables_dump => '-t mangle -nvx --line-numbers -L '.$self->config('client_out_chain'));
  });


  # my $resp = rt_add_replace({id=>11, ip=>'1.2.3.4', rt=>0});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error
  $app->helper(rt_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $client_out_chain = $self->config('client_out_chain');
    # create rule dump
    my $dump_m_out = $self->rt_dump;
    die "Error dumping rules $client_out_chain in mangle table!" unless $dump_m_out;

    my $ip = $v->{ip};
    my $ff = 0;
    my $failure = undef;
    for (my $i = 2; $i < @$dump_m_out; $i++) { # skip first 2 lines
      $_ = $dump_m_out->[$i];
      # n pkt bytes MARK all -- * * 10.15.0.2 0.0.0.0/0 /* id */ MARK set 0x2
      # n pkt bytes      all -- * * 10.15.0.2 0.0.0.0/0 /* id */
      if (/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \Q$ip\E\s+ \S+\s+ \/\*\s+ \d+\s+ \*\/.*/x) {
        my $ri = $1;
        if (!$ff) {
          $self->rlog("Marking-rules sync. Replacing rule #$ri ip $ip in mangle table.");
          $ff = 1;
          if ($self->system(iptables => "-t mangle -R $client_out_chain $ri -s $ip -m comment --comment $v->{id} ".$self->rt_marks($v->{rt}) )) {
            $failure = "Marking-rules sync error. Can't replace rule #$ri in mangle table.";
          }
        } else {
          $self->rlog("Marking-rules sync. Deleting duplicate rule #$ri ip $ip in mangle table.");
          if ($self->system(iptables => "-t mangle -D $client_out_chain $ri")) {
            # just warn, count it non-fatal
            $self->rlog("Marking-rules sync error. Can't delete rule #$ri from mangle table.");
          }
        }
      } # if regex
    } # for dump
    if (!$ff) { # if not found, add rule
      $self->rlog("Marking-rules sync. Appending rule ip $ip to mangle table.");
      if (!$self->system(iptables => "-t mangle -A $client_out_chain -s $ip -m comment --comment $v->{id} ".$self->rt_marks($v->{rt}) )) {
        # successfully added
        return 1;

      } else {
        $failure = "Marking-rules sync error. Can't append rule ip $ip to mangle table.";
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

    my $client_out_chain = $self->config('client_out_chain');
    # create rule dump
    my $dump_m_out = $self->rt_dump;
    die "Error dumping rules $client_out_chain in mangle table!" unless $dump_m_out;

    my $ret = 0;
    my $failure = undef;
    for (my $i = 2; $i < @$dump_m_out; $i++) { # skip first 2 lines
      $_ = $dump_m_out->[$i];
      # n pkt bytes MARK all -- * * 10.15.0.2 0.0.0.0/0 /* id */ MARK set 0x2
      # n pkt bytes      all -- * * 10.15.0.2 0.0.0.0/0 /* id */
      if (/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x) {
        my $ri = $1;
        $self->rlog("Marking-rules sync. Rule #$ri ip $2 has been requested to delete. Deleting.");
        $ret = 1;
        if ($self->system(iptables => "-t mangle -D $client_out_chain $ri")) {
          my $msg = "Marking-rules sync error. Can't delete rule from mangle table.";
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
