package Gwsyn::Plugin::fw_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};


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
          $self->system(iptables => "-t fliter -D $client_in_chain $ri")
        },
        zero_sub => sub { $self->system(iptables => "-t fliter -Z $client_in_chain") },
        # n pkt bytes ACCEPT all -- * * 0.0.0.0/0 1.2.3.4 /* id */
        # n pkt bytes DROP   all -- * * 0.0.0.0/0 1.2.3.5 /* id */
        re1 => sub {
          my $id = shift;
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \S+\s+ (\S+)\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {
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
        zero_sub => sub { $self->system(iptables => "-t fliter -Z $client_out_chain") },
        # n pkt bytes ACCEPT all -- * * 1.2.3.4 0.0.0.0/0 /* id */ MAC 11:22:33:44:55:66
        # n pkt bytes DROP   all -- * * 1.2.3.5 0.0.0.0/0 /* id */
        re1 => sub {
          my $id = shift;
          qr/^\s*(\d+)\s+ \S+\s+ \S+\s+ \S*\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ (\S+)\s+ \S+\s+ \/\*\s+ \Q$id\E\s+ \*\/.*/x
        },
        re_stat => sub {
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
          $self->system(iptables => "-t mangle -A $client_in_chain -d $v->{ip} -m comment --comment $v->{id}")
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_in_chain $ri -d $v->{ip} -m comment --comment $v->{id}")
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
          $self->system(iptables => "-t mangle -A $client_out_chain -s $v->{ip} -m comment --comment $v->{id}")
        },
        replace_sub => sub {
          my ($ri, $v) = @_; # rule index, {id=>1, etc}
          $self->system(iptables => "-t mangle -R $client_out_chain $ri -s $v->{ip} -m comment --comment $v->{id}")
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
      croak "Matang $n matanga!" unless $m;

      my $ff = 0;

      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

      for (my $i = 2; $i < @$dump; $i++) { # skip first 2 lines
        if ($dump->[$i] =~ $m->{re1}($v->{id})) {
          my $ri = $1;
          if (!$ff) {
            $self->rlog("$m->{rule_desc} sync. Replacing rule #$ri id $v->{id} ip $2 in $m->{table} table.");
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
            $self->rlog("$m->{rule_desc} sync. Deleting duplicate rule #$ri id $v->{id} ip $2 in $m->{table} table.");
            if ( $m->{delete_sub}($ri) ) {
              # just warn, count it non-fatal
              $self->rlog("$m->{rule_desc} sync error. Can't delete rule #$ri from $m->{table} table.");
            }
          }
        } # if regex
      } # for dump

      if (!$ff) { # if not found, add rule
        $self->rlog("$m->{rule_desc} sync. Appending rule id $v->{id} ip $v->{ip} to $m->{table} table.");
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

    die $failure if $failure;

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
      croak "Matang $n matanga!" unless $m;

      my $dump = $m->{dump_sub}();
      die "Error dumping rules $m->{chain} in $m->{table} table!" unless $dump;

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

    die $failure if $failure;

    if ($ret && @found_check < 4) {
      $self->rlog('Deleted only '.join('/', @found_check).' tables/chains. This is not normal, just warn you.');
    }

    return $ret;
  });


  # my $resp = fw_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT'});
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error,
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
    $ff = 0;
    $skip = 0;
    $skip_duplicate = 0;

    for (@mangle_content) {
      #*mangle
      #:pipe_in_inet_clients - [0:0]
      #:pipe_out_inet_clients - [0:0]
      # 450
      #(1)-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
      #(2)-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
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
            print $fh "-A $client_in_chain -d $v->{ip} $c\n";
            print $fh "-A $client_out_chain -s $v->{ip} $c\n";
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
      print $fh "-A $client_in_chain -d $v->{ip} $c\n";
      print $fh "-A $client_out_chain -s $v->{ip} $c\n";
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
      #(1)-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
      #(2)-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
      #COMMIT
      if ($skip > 0) {
        if (/^-A\ /x) {
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


  # my $resp = fw_create_full([{id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT'}, ...]);
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
    my $prof = $self->config('my_profile');

    my $fh = eval { $fwfile->open('>') } or die "Can't create firewall file: $!";

    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
    print $fh "*filter\n";
    print $fh ":$client_in_chain - [0:0]\n";
    print $fh ":$client_out_chain - [0:0]\n";
    print $fh ":ICMP_ONLY - [0:0]\n";
    print $fh ":HTTP_ICMP - [0:0]\n";
    print $fh ":HTTP_IM_ICMP - [0:0]\n";
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
      next if (!$_->{profile} or $_->{profile} ne $prof); # skip clients from invalid profiles
      print $fh "# $_->{id}\n";
      my $c = "-m comment --comment $_->{id}";
      print $fh "-A $client_in_chain -d $_->{ip} $c -j $_->{defjump}\n";
      my $m = ($_->{mac}) ? "-m mac --mac-source $_->{mac} " : '';
      print $fh "-A $client_out_chain -s $_->{ip} $c ${m}-j $_->{defjump}\n";
      $mangle_append .= "# $_->{id}\n";
      $mangle_append .= "-A $client_in_chain -d $_->{ip} $c\n";
      $mangle_append .= "-A $client_out_chain -s $_->{ip} $c\n";
    }
    print $fh "COMMIT\n\n";
    print $fh "*mangle\n";
    print $fh ":$client_in_chain - [0:0]\n";
    print $fh ":$client_out_chain - [0:0]\n";
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
    # note: iptables_restore still flushes user chains mentioned in file
    if (!$self->system(iptables_restore => "--noflush < $rulefile")) {
      return 1; # success
    } else {
      die "iptables_restore error";
    }
  });

}

1;
