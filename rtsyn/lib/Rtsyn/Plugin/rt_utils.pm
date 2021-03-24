package Rtsyn::Plugin::rt_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # internal
  # $txt = $_rt_marks->($rt)
  my $_rt_marks = sub {
    my $rt = shift;
    # 0 - ufanet
    # 1 - beeline
    return $rt eq 1 ? '-j MARK --set-mark 2' : '';
  };


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
          $self->system(iptables => "-t mangle -A $client_out_chain -s $v->{ip} -m comment --comment $v->{id} ".$_rt_marks->($v->{rt}))
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id} ".$_rt_marks->($v->{rt}))
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


  # my $resp = rt_add_replace_rules({id=>11, ip=>'1.2.3.4', rt=>0});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error
  $app->helper(rt_add_replace_rules => sub {
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
          $self->rlog("$m->{rule_desc} sync. Replacing client id $v->{id} Rule #$ri ip $2 in $m->{table} table.");
          $ff = 1;
          if ( $m->{replace_sub}($ri, $v) ) {
            $failure = "$m->{rule_desc} sync error. Can't replace rule #$ri in $m->{table} table.";
          }
        } else {
          $self->rlog("$m->{rule_desc} sync. Deleting duplicate client id $v->{id} Rule #$ri ip $2 in $m->{table} table.");
          if ( $m->{delete_sub}($ri) ) {
            # just warn, count it non-fatal
            $self->rlog("$m->{rule_desc} sync error. Can't delete rule #$ri from $m->{table} table.");
          }
        }
      } # if regex
    } # for dump

    if (!$ff) { # if not found, add rule
      $self->rlog("$m->{rule_desc} sync. Appending client id $v->{id} Rule ip $v->{ip} to $m->{table} table.");
      if ( !$m->{add_sub}($v) ) {
        # successfully added
        return 1;

      } else {
        $failure = "$m->{rule_desc} sync error. Can't append client id $v->{id} rule to $m->{table} table.";
      }
    }

    die $failure if $failure;

    # successfully replaced
    return 1;
  });


  # my $resp = rt_delete_rules($id);
  # returns 1-deleted/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(rt_delete_rules => sub {
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
        $self->rlog("$m->{rule_desc} sync. Client id $id Rule #$ri ip $2 has been requested to delete. Deleting.");
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


  # my $resp = rt_add_replace({id=>11, ip=>'1.2.3.4', rt=>0});
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(rt_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $rulefile = path($self->config('firewall_file'));
    my $client_out_chain = $self->config('client_out_chain');
    my $fh = eval { $rulefile->open('<') } or die "Can't read firewall file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close firewall file: $!";

    $fh = eval { $rulefile->open('>') } or die "Can't reopen firewall file: $!";
    my $ret = 0;
    my $ff = 0;

    for (@content) {
      # WARNING: this is autogenerated file, don't run or change it!
      #*mangle
      #:pipe_out_inet_clients - [0:0]
      #-A pipe_out_inet_clients -s 10.14.0.1 -m comment --comment 450\s
      #-A pipe_out_inet_clients -s 10.14.0.1 -m comment --comment 450 -j MARK --set-mark 2
      #COMMIT
      if (/-s\ ([0-9.]+)\s+-m\ comment\s+--comment\ (\d+)\s*(?:-j.*)?$/x) {
        #say "$_, IP: $1, ID: $2";
        if ($2 == $v->{id}) {
          if (!$ff) {
            # replace same id
            print $fh "-A $client_out_chain -s $v->{ip} -m comment --comment $v->{id} ".$_rt_marks->($v->{rt})."\n";
            $ret = 1;
            $ff = 1;
          } else {
            # skip duplicate id line
            $self->rlog("Found duplicate ID in firewall file, conflicting line deleted.");
            $ret = 1;
          }
        } elsif ($1 eq $v->{ip}) {
          $self->rlog("Found duplicate IP in firewall file, conflicting line deleted.");
          $ret = 1;
        } else {
          print $fh "$_\n"; # just copy other lines
        }
      } else {
        # unparsable line - copy, but skip 'COMMIT'
        print $fh "$_\n" unless /^COMMIT/;
      }
    }

    if (!$ff) { # if not found, add line
      print $fh "-A $client_out_chain -s $v->{ip} -m comment --comment $v->{id} ".$_rt_marks->($v->{rt})."\n";
      $ret = 1;
    }

    print $fh "COMMIT\n";
    $fh->close or die "Can't close firewall file: $!";

    return $ret;
  });


  # my $resp = rt_delete($id);
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(rt_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $rulefile = path($self->config('firewall_file'));
    my $fh = eval { $rulefile->open('<') } or die "Can't read firewall file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close firewall file: $!";

    $fh = eval { $rulefile->open('>') } or die "Can't reopen firewall file: $!";
    my $ret = 0;

    for (@content) {
      # WARNING: this is autogenerated file, don't run or change it!
      #*mangle
      #:pipe_out_inet_clients - [0:0]
      #-A pipe_out_inet_clients -s 10.14.0.1 -m comment --comment 450\s
      #-A pipe_out_inet_clients -s 10.14.0.1 -m comment --comment 450 -j MARK --set-mark 2
      #COMMIT
      if (/--comment\ \Q$id\E\s*(?:-j.*)?$/x) {
        #say "Skipped line $_";
        $self->rlog("Found duplicate ID in firewall file, conflicting line deleted.") if $ret;
        $ret = 1;
        next;
      }
      print $fh "$_\n";
    }

    $fh->close or die "Can't close firewall file: $!";

    return $ret;
  });


  # my $resp = rt_create_full([{id=>11, ip=>'1.2.3.4', rt=>0, profile=>'plk'}, ...]);
  # fully updates /var/r2d2/firewall-rtsyn.clients,
  # returns 1-need apply/0-(not returned) on success,
  #   dies with 'error string' on error
  $app->helper(rt_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $rulefile = path($self->config('firewall_file'));
    my $client_out_chain = $self->config('client_out_chain');

    my $fh = eval { $rulefile->open('>') } or die "Can't create firewall file: $!";

    # header
    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
    print $fh "*mangle\n";
    print $fh ":$client_out_chain - [0:0]\n\n";

    # data
    for (@$va) {
      next if !$self->is_myprofile($_->{profile}); # skip clients from invalid profiles
      #print $fh "# $_->{id}\n";
      print $fh "-A $client_out_chain -s $_->{ip} -m comment --comment $_->{id} ".$_rt_marks->($_->{rt})."\n";
    }

    print $fh "COMMIT\n";
    $fh->close or die "Can't close firewall file: $!";

    # always need apply
    return 1;
  });


  # my $err = $app->rt_apply()
  # returns 1-success, dies on error
  $app->helper(rt_apply => sub {
    my $self = shift;

    # reload rules with iptables_restore
    my $rulefile = $self->config('firewall_file');
    # note: iptables_restore still flushes user chains mentioned in file
    if (!$self->system(iptables_restore => "--noflush < $rulefile")) {
      return 1; # success
    } else {
      die "iptables_restore error";
    }
  });

}

1;
