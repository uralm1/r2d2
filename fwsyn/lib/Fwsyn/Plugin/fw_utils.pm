package Fwsyn::Plugin::fw_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # internal
  # $txt = $_blk_mark->({blocked=>1, qs=>2});
  my $_blk_mark = sub {
    my $v = shift;
    my $q = $v->{qs};
    return $v->{blocked} ? ($q eq q{2} || $q eq q{3} ? " -j MARK --set-mark $q" : q{}) : q{};
  };


  # {} = fw_matang;
  $app->helper(fw_matang => sub {
    my $self = shift;
    my $client_in_chain = $self->config('client_in_chain');
    my $client_out_chain = $self->config('client_out_chain');
    return {
      'f_in' => {
        table => 'filter',
        chain => $client_in_chain,
        dump_sub => sub { $self->system(iptables_dump => "-t filter -nvx --line-numbers -L $client_in_chain") },
        add_sub => sub {
          my $v = shift; # {id=>1, etc}
          $self->system(iptables => "-t filter -A $client_in_chain -d $v->{ip} -m comment --comment $v->{id} -j $v->{defjump}")
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t filter -R $client_in_chain $ri -d $v->{ip} -m comment --comment $v->{id} -j $v->{defjump}")
        },
        delete_sub => sub {
          my $ri = shift; # rule index
          $self->system(iptables => "-t filter -D $client_in_chain $ri")
        },
        zero_sub => sub { $self->system(iptables => "-t filter -Z $client_in_chain") },
        # n pkt bytes ACCEPT all -- * * 0.0.0.0/0 1.2.3.4 /* id */
        # n pkt bytes DROP   all -- * * 0.0.0.0/0 1.2.3.5 /* id */
        re1 => sub {
          my $id = shift;
          # $1 - n, $2 - ip
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \S+\s+ (\S+)\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {
          # $1 - n, $2 - bytes, $3 - ip, $4 - id
          qr/^\s*(\d+)\s+ \S+\s+ (\S+)\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \S+\s+ (\S+)\s+ \/\*\s+ (\d+)\s+ \*\/.*/x
        },
        rule_desc => 'In-rules',
      },

      'f_out' => {
        table => 'filter',
        chain => $client_out_chain,
        dump_sub => sub { $self->system(iptables_dump => "-t filter -nvx --line-numbers -L $client_out_chain") },
        add_sub => sub {
          my $v = shift; # {id=>1, etc}
          my $m = ($v->{mac}) ? "-m mac --mac-source $v->{mac} " : '';
          $self->system(iptables => "-t filter -A $client_out_chain -s $v->{ip} -m comment --comment $v->{id} ${m}-j $v->{defjump}")
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          my $m = ($v->{mac}) ? "-m mac --mac-source $v->{mac} " : '';
          $self->system(iptables => "-t filter -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id} ${m}-j $v->{defjump}")
        },
        delete_sub => sub {
          my $ri = shift; # rule index
          $self->system(iptables => "-t filter -D $client_out_chain $ri")
        },
        zero_sub => sub { $self->system(iptables => "-t filter -Z $client_out_chain") },
        # n pkt bytes ACCEPT all -- * * 1.2.3.4 0.0.0.0/0 /* id */ MAC 11:22:33:44:55:66
        # n pkt bytes DROP   all -- * * 1.2.3.5 0.0.0.0/0 /* id */
        re1 => sub {
          my $id = shift;
          # $1 - n, $2 - ip
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {
          # $1 - n, $2 - bytes, $3 - ip, $4 - id
          qr/^\s*(\d+)\s+ \S+\s+ (\S+)\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ (\d+)\s+ \*\/.*/x
        },
        rule_desc => 'Out-rules',
      },

      'm_in' => {
        table => 'mangle',
        chain => $client_in_chain,
        dump_sub => sub { $self->system(iptables_dump => "-t mangle -nvx --line-numbers -L $client_in_chain") },
        add_sub => sub {
          my $v = shift; # {id=>1, etc}
          $self->system(iptables => "-t mangle -A $client_in_chain -d $v->{ip} -m comment --comment $v->{id}".$_blk_mark->($v))
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_in_chain $ri -d $v->{ip} -m comment --comment $v->{id}".$_blk_mark->($v))
        },
        delete_sub => sub {
          my $ri = shift; # rule index
          $self->system(iptables => "-t mangle -D $client_in_chain $ri")
        },
        zero_sub => sub {},
        # n pkt bytes MARK all -- * * 0.0.0.0/0 1.2.3.4 /* id */ MARK set 0x4
        # n pkt bytes      all -- * * 0.0.0.0/0 1.2.3.5 /* id */
        re1 => sub {
          my $id = shift;
          # $1 - n, $2 - ip
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \S+\s+ (\S+)\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {},
        rule_desc => 'In-rules',
      },

      'm_out' => {
        table => 'mangle',
        chain => $client_out_chain,
        dump_sub => sub { $self->system(iptables_dump => "-t mangle -nvx --line-numbers -L $client_out_chain") },
        add_sub => sub {
          my $v = shift; # {id=>1, etc}
          $self->system(iptables => "-t mangle -A $client_out_chain -s $v->{ip} -m comment --comment $v->{id}".$_blk_mark->($v))
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id}".$_blk_mark->($v))
        },
        delete_sub => sub {
          my $ri = shift; # rule index
          $self->system(iptables => "-t mangle -D $client_out_chain $ri")
        },
        zero_sub => sub {},
        # n pkt bytes MARK all -- * * 1.2.3.4 0.0.0.0/0 /* id */ MARK set 0x4
        # n pkt bytes      all -- * * 1.2.3.5 0.0.0.0/0 /* id */
        re1 => sub {
          my $id = shift;
          # $1 - n, $2 - ip
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {},
        rule_desc => 'Out-rules',
      },

    }
  });


  # my $resp = fw_add_replace_rules({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT'});
  # returns 1-added or replaced/0-(not returned) on success,
  #   dies with 'error string' on error,
  $app->helper(fw_add_replace_rules => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $matang = $self->fw_matang;
    my $failure = undef;
    my @replaced_check;
    my @added_check;
    for my $n (qw/f_in f_out m_in m_out/) {
      my $m = $matang->{$n};
      die "Matang $n matanga!" unless $m;

      my $ff = 0;

      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table!\n" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re1}($v->{id})) {
          my $ri = $1;
          if (!$ff) {
            $self->rlog("$m->{rule_desc} $m->{table} sync. Replacing rule #$ri id $v->{id} ip $2 in $m->{table} table.");
            $ff = 1;
            push @replaced_check, $n;
            if ( $m->{replace_sub}($ri, $v) ) {
              my $msg = "$m->{rule_desc} sync error. Can't replace rule #$ri in $m->{table} table.";
              if ($failure) {
                $self->rlog($msg); # count not first errors non-fatal
              } else {
                $failure = $msg;
              }
            }
          } else {
            $self->rlog("$m->{rule_desc} $m->{table} sync. Deleting duplicate rule #$ri id $v->{id} ip $2 in $m->{table} table.");
            if ( $m->{delete_sub}($ri) ) {
              # just warn, count it non-fatal
              $self->rlog("$m->{rule_desc} sync error. Can't delete rule #$ri from $m->{table} table.");
            }
          }
        } # if regex
      } # for dump

      if (!$ff) { # if not found, add rule
        $self->rlog("$m->{rule_desc} $m->{table} sync. Appending rule id $v->{id} ip $v->{ip} to $m->{table} table.");
        if ( !$m->{add_sub}($v) ) {
          # successfully added
          push @added_check, $n;

        } else {
          my $msg = "$m->{rule_desc} sync error. Can't append rule id $v->{id} to $m->{table} table.";
          if ($failure) {
            $self->rlog($msg); # count not first errors non-fatal
          } else {
            $failure = $msg;
          }
        }
      }

    } # for filter in/out, mangle in/out

    die "$failure\n" if $failure;

    if (@added_check && @added_check < 4) {
      $self->rlog('Added only '.join('/', @added_check).' tables/chains. This is not normal, just warn you.');
    }
    if (@replaced_check && @replaced_check < 4) {
      $self->rlog('Replaced only '.join('/', @added_check).' tables/chains. This is not normal, just warn you.');
    }

    return 1;
  });


  # my $resp = fw_delete_rules($id);
  # returns 1-deleted/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(fw_delete_rules => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $matang = $self->fw_matang;
    my $ret = 0;
    my $failure = undef;
    my @found_check;
    for my $n (qw/f_in f_out m_in m_out/) {
      my $m = $matang->{$n};
      die "Matang $n matanga!" unless $m;

      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table!\n" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re1}($id)) {
          my $ri = $1;
          $self->rlog("$m->{rule_desc} sync. Rule #$ri ip $2 has been requested to delete. Deleting.");
          $ret = 1;
          push @found_check, $n;
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
    } # for filter in/out, mangle in/out

    die "$failure\n" if $failure;

    if ($ret && @found_check < 4) {
      $self->rlog('Deleted in only '.join('/', @found_check).' tables/chains. This is not normal, just warn you.');
    }

    return $ret;
  });


  # my $resp = fw_block_rules($id, $qs);
  #   $qs - 0-unblock, 2-limit, 3-block,
  # returns 1-done/0-not found on success,
  #   dies with 'error string' on error
  $app->helper(fw_block_rules => sub {
    my ($self, $id, $qs) = @_;
    croak 'Bad arguments' unless defined $id && defined $qs;

    my $matang = $self->fw_matang;
    my $ret = 0;
    my $failure = undef;
    my @found_check;
    for my $n (qw/m_in m_out/) {
      my $m = $matang->{$n};
      die "Matang $n matanga!" unless $m;

      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table!\n" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re1}($id)) {
          my $ri = $1;
          my $op = $qs == 0 ? 'Unblocking' : "Blocking ($qs)";
          $self->rlog("$m->{rule_desc}. $op rule #$ri ip $2.");
          $ret = 1;
          push @found_check, $n;
          if ( $m->{replace_sub}($ri, {id=>$id, ip=>$2, blocked=>1, qs=>$qs}) ) {
            my $msg = "$m->{rule_desc} block/unblock error on $m->{table} table.";
            if ($failure) {
              $self->rlog($msg); # count not first errors non-fatal
            } else {
              $failure = $msg;
            }
          }
        } # if regex
      } # for dump
    } # for mangle in/out

    die "$failure\n" if $failure;

    if ($ret && @found_check < 2) {
      $self->rlog('(Un)Blocked in only '.join('/', @found_check).' tables/chains. This is not normal, just warn you.');
    }

    return $ret;
  });


  # my $resp = fw_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT', qs=>2, blocked=>0});
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(fw_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $fwfile = path($self->config('firewall_file'));
    my $client_in_chain = $self->config('client_in_chain');
    my $client_out_chain = $self->config('client_out_chain');
    my $fh = eval { $fwfile->open('<') } or die "Can't read firewall file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close firewall file: $!";

    # split @content to filter and mangle WITHOUT "COMMIT" lines
    my @filter_content;
    my @mangle_content;
    my $mode = 0;
    for (@content) {
      if (/^\*filter$/x) { $mode = 1; }
      elsif (/^\*mangle$/x) { $mode = 2; }
      if ($mode == 1) {
        if (/^COMMIT$/x) { $mode = 0; next; }
        push @filter_content, $_;
      } elsif ($mode == 2) {
        if (/^COMMIT$/x) { $mode = 0; next; }
        push @mangle_content, $_;
      }
    }
    undef @content;

    $fh = eval { $fwfile->open('>') } or die "Can't reopen firewall file: $!";
    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
    my $c = "-m comment --comment $v->{id}";
    my $ret = 0; # FIRST ROUND on filter table
    my $ff = 0;
    my $skip = 0;
    my $skip_duplicate = 0;

    for (@filter_content) {
      #*filter
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      #:ICMP_ONLY - [0:0]
      #:HTTP_ICMP - [0:0]
      #:HTTP_IM_ICMP - [0:0]
      #-A ICMP_ONLY -p icmp -j ACCEPT etc...
      #
      # 450
      #(1)-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
      #(2)-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
      if ($skip > 0) {
        if (/^-A\ /x) {
          #say "Skipped line ($skip) $_";
          $skip++;
          next;
        } elsif (/^$/x) {
          $skip = 0;
          next;
        } else {
          unless ($skip_duplicate) {
            # here actual replace
            print $fh "# $v->{id}\n";
            print $fh "-A $client_in_chain -d $v->{ip} $c -j $v->{defjump}\n";
            my $m = ($v->{mac}) ? "-m mac --mac-source $v->{mac} " : '';
            print $fh "-A $client_out_chain -s $v->{ip} $c ${m}-j $v->{defjump}\n";
          } else {
            $skip_duplicate = 0;
          }
          $skip = 0;
        }
      }
      if (/^\#\ \Q$v->{id}\E$/x) {
        if (!$ff) {
          # replace same id but after skip
          #say "Skipped line ($skip) $_";
          $ff = 1;
        } else {
          # secondary duplicating id - skip it
          $self->rlog("Found duplicate ID in firewall file *filter section, conflicting lines deleted.");
          $skip_duplicate = 1;
        }
        $skip = 1;
        $ret = 1;
        next;
      }
      print $fh "$_\n"; # just copy other lines
    }

    if (!$ff or ($skip > 0 and !$skip_duplicate)) { # if not found or last line, add new
      print $fh "# $v->{id}\n";
      print $fh "-A $client_in_chain -d $v->{ip} $c -j $v->{defjump}\n";
      my $m = ($v->{mac}) ? "-m mac --mac-source $v->{mac} " : '';
      print $fh "-A $client_out_chain -s $v->{ip} $c ${m}-j $v->{defjump}\n";
      $ret = 1;
    }

    print $fh "COMMIT\n\n"; # AND... NEXT ROUND on mangle table
    my $jb = $_blk_mark->($v); # target for blocking
    my $blkcmnt = $jb eq q{} ? '#' : q{}; # optimize not blocked lines
    $ff = 0;
    $skip = 0;
    $skip_duplicate = 0;

    for (@mangle_content) {
      #*mangle
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      # 450
      #(1)#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
      #(2)#-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
      if ($skip > 0) {
        if (/^\#?-A\ /x) {
          #say "Skipped line ($skip) $_";
          $skip++;
          next;
        } elsif (/^$/x) {
          $skip = 0;
          next;
        } else {
          unless ($skip_duplicate) {
            # here actual replace
            print $fh "# $v->{id}\n";
            print $fh "$blkcmnt-A $client_in_chain -d $v->{ip} ${c}${jb}\n";
            print $fh "$blkcmnt-A $client_out_chain -s $v->{ip} ${c}${jb}\n";
          } else {
            $skip_duplicate = 0;
          }
          $skip = 0;
        }
      }
      if (/^\#\ \Q$v->{id}\E$/x) {
        if (!$ff) {
          # replace same id but after skip
          #say "Skipped line ($skip) $_";
          $ff = 1;
        } else {
          # secondary duplicating id - skip it
          $self->rlog("Found duplicate ID in firewall file *mangle section, conflicting lines deleted.");
          $skip_duplicate = 1;
        }
        $skip = 1;
        $ret = 1;
        next;
      }
      print $fh "$_\n"; # just copy other lines
    }

    if (!$ff or ($skip > 0 and !$skip_duplicate)) { # if not found or last line, add new
      print $fh "# $v->{id}\n";
      print $fh "$blkcmnt-A $client_in_chain -d $v->{ip} ${c}${jb}\n";
      print $fh "$blkcmnt-A $client_out_chain -s $v->{ip} ${c}${jb}\n";
      $ret = 1;
    }

    print $fh "COMMIT\n";

    $fh->close or die "Can't close firewall file: $!";

    return $ret;
  });


  # my $resp = fw_delete($id);
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(fw_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $fwfile = path($self->config('firewall_file'));
    my $fh = eval { $fwfile->open('<') } or die "Can't read firewall file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close firewall file: $!";

    $fh = eval { $fwfile->open('>') } or die "Can't reopen firewall file: $!";
    my $ret = 0;
    my $skip = 0;
    my $dup_detector = 0;

    for (@content) {
      # WARNING: this is autogenerated file, don't run or change it!
      #*filter
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      #:ICMP_ONLY - [0:0]
      #:HTTP_ICMP - [0:0]
      #:HTTP_IM_ICMP - [0:0]
      #-A ICMP_ONLY -p icmp -j ACCEPT etc...
      #
      # 450
      #(1)-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
      #(2)-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
      #COMMIT
      #
      #*mangle
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      # 450
      #(1)#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
      #(2)#-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
      #COMMIT
      if ($skip > 0) {
        if (/^\#?-A\ /x) {
          #say "Skipped line ($skip) $_";
          $skip++;
          next;
        } elsif (/^$/x) {
          $skip = 0;
          next;
        } else {
          $skip = 0;
        }
      }
      if (/^\#\ \Q$id\E$/x) {
        #say "Skipped line ($skip) $_";
        if ($dup_detector++ > 1) {
          $self->rlog("Found duplicate ID in firewall file, conflicting lines deleted.");
          $dup_detector-=2;
        }
        $skip = 1;
        $ret = 1;
        next;
      }
      print $fh "$_\n"; # just copy other lines
    }

    $fh->close or die "Can't close firewall file: $!";

    return $ret;
  });


  # my $resp = fw_block($id, $qs);
  #   $qs - 0-unblock, 2-limit, 3-block,
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(fw_block => sub {
    my ($self, $id, $qs) = @_;
    croak 'Bad arguments' unless defined $id && defined $qs;

    my $fwfile = path($self->config('firewall_file'));
    my $client_in_chain = $self->config('client_in_chain');
    my $client_out_chain = $self->config('client_out_chain');
    my $fh = eval { $fwfile->open('<') } or die "Can't read firewall file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close firewall file: $!";

    $fh = eval { $fwfile->open('>') } or die "Can't reopen firewall file: $!";
    # cut mangle_content WITHOUT "COMMIT" line and keep others
    my @mangle_content;
    my $mode = 0;
    for (@content) {
      if (/^\*mangle$/x) { $mode = 2; }
      if ($mode == 0) {
        print $fh "$_\n";
      } elsif ($mode == 2) {
        if (/^COMMIT$/x) { $mode = 0; next; }
        push @mangle_content, $_;
      }
    }
    undef @content;

    # now work on mangle content
    my $ret = 0;
    my $jb = $_blk_mark->({blocked=>1, qs=>$qs}); # target for blocking
    my $ff = 0;
    my $skip = 0;

    for (@mangle_content) {
      #*mangle
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      # 450
      #(1)-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
      #(2)-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
      # 451
      #(1)-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 2
      #(2)-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 2
      if ($skip > 0) {
        if (/^-A\ (\S+)\s+ (-[ds]\ \S+)\s+ -m\ comment\s+ --comment\ \Q$id\E/x) {
          # CHAIN: $1, "-d/s IP": $2
          if ($1 eq $client_in_chain || $1 eq $client_out_chain) {
            # replace good rule
            print $fh "-A $1 $2 -m comment --comment ${id}${jb}\n";
            $ret = 1;
          }
          $skip++;
          next;
        } elsif (/^-A\ /x) {
          $skip++;
          next;
        } elsif (/^$/x) {
          $skip = 0;
          next;
        } else {
          $skip = 0;
        }
      }
      if (/^\#\ \Q$id\E$/x) {
        if (!$ff) {
          $ff = 1;
        } else {
          # secondary duplicating id - warn about it
          $self->rlog("Found duplicate ID in firewall file *mangle section.");
        }
        $skip = 1;
        # copy id line too
      }
      print $fh "$_\n"; # just copy other lines
    }

    print $fh "COMMIT\n";

    $fh->close or die "Can't close firewall file: $!";

    return $ret;
  });


  # my $resp = fw_create_full([{id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT', qs=>2, blocked=>0}, ...]);
  # fully updates /var/r2d2/firewall.clients,
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error,
  #   will check mac and add line without it if not set.
  $app->helper(fw_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $fwfile = path($self->config('firewall_file'));
    my $client_in_chain = $self->config('client_in_chain');
    my $client_out_chain = $self->config('client_out_chain');
    my $cmnt = $self->config('old_iptables_compatibility') ? '#' : q{};

    my $fh = eval { $fwfile->open('>') } or die "Can't create firewall file: $!";

    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n";
    print $fh "# Compatibility mode is switched on, you must flush user chains prior calling iptables-restore.\n"
      if $self->config('old_iptables_compatibility');
    print $fh "\n";
    print $fh "*filter\n";
    print $fh "$cmnt:$client_in_chain - [0:0]\n";
    print $fh "$cmnt:$client_out_chain - [0:0]\n";
    print $fh "$cmnt:ICMP_ONLY - [0:0]\n";
    print $fh "$cmnt:HTTP_ICMP - [0:0]\n";
    print $fh "$cmnt:HTTP_IM_ICMP - [0:0]\n";
    print $fh "-A ICMP_ONLY -p icmp -j ACCEPT\n";
    print $fh "-A HTTP_ICMP -p icmp -j ACCEPT\n";
    print $fh "-A HTTP_ICMP -p tcp -m multiport --source-ports 80,8080,81,3128,443 -j ACCEPT\n";
    print $fh "-A HTTP_ICMP -p tcp -m multiport --destination-ports 80,8080,81,3128,443 -j ACCEPT\n";
    print $fh "-A HTTP_IM_ICMP -p icmp -j ACCEPT\n";
    print $fh "-A HTTP_IM_ICMP -p tcp -j HTTP_ICMP\n";
    print $fh "-A HTTP_IM_ICMP -p tcp -m multiport --source-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT\n";
    print $fh "-A HTTP_IM_ICMP -p tcp -m multiport --destination-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT\n";
    print $fh "\n";

    # data
    my $mangle_append = '';
    for (@$va) {
      next if !$self->is_myprofile($_->{profile}); # skip clients from invalid profiles
      print $fh "# $_->{id}\n";
      my $c = "-m comment --comment $_->{id}";
      print $fh "-A $client_in_chain -d $_->{ip} $c -j $_->{defjump}\n";
      my $m = ($_->{mac}) ? "-m mac --mac-source $_->{mac} " : q{};
      print $fh "-A $client_out_chain -s $_->{ip} $c ${m}-j $_->{defjump}\n";
      my $jb = $_blk_mark->($_); # target for blocking
      my $blkcmnt = $jb eq q{} ? '#' : q{}; # optimize not blocked
      $mangle_append .= "# $_->{id}\n";
      $mangle_append .= "$blkcmnt-A $client_in_chain -d $_->{ip} ${c}${jb}\n";
      $mangle_append .= "$blkcmnt-A $client_out_chain -s $_->{ip} ${c}${jb}\n";
    }
    print $fh "COMMIT\n\n";
    print $fh "*mangle\n";
    print $fh "$cmnt:$client_in_chain - [0:0]\n";
    print $fh "$cmnt:$client_out_chain - [0:0]\n";
    print $fh $mangle_append;
    print $fh "COMMIT\n";

    $fh->close or die "Can't close firewall file: $!";

    # always need apply
    return 1;
  });


  # my $err = $app->fw_apply()
  # returns 1-success, dies on error
  $app->helper(fw_apply => sub {
    my $self = shift;

    # reload rules with iptables_restore
    my $rulefile = $self->config('firewall_file');

    # note: *NEW VERSIONS ONLY* iptables_restore still flushes user chains mentioned in file

    if ($self->config('old_iptables_compatibility')) {
      # old iptables_restore doesn't flush user chains - so do it now
      my $client_in_chain = $self->config('client_in_chain');
      my $client_out_chain = $self->config('client_out_chain');
      $self->system(iptables => "-t filter -F $client_in_chain");
      $self->system(iptables => "-t filter -F $client_out_chain");
      $self->system(iptables => "-t filter -F ICMP_ONLY");
      $self->system(iptables => "-t filter -F HTTP_ICMP");
      $self->system(iptables => "-t filter -F HTTP_IM_ICMP");
      $self->system(iptables => "-t mangle -F $client_in_chain");
      $self->system(iptables => "-t mangle -F $client_out_chain");
    }

    if (!$self->system(iptables_restore => "--noflush < $rulefile")) {
      return 1; # success
    } else {
      die "iptables_restore error\n";
    }
  });

}

1;
