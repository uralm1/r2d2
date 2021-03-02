package Gwsyn::Plugin::dhcp_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $resp = dhcp_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55:66'});
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error,
  #   will check ip/mac/no_dhcp flag and skip line if not set.
  $app->helper(dhcp_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $fh = eval { $dhcpfile->open('<') } or die "Can't read dhcphosts file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close dhcphosts file: $!";

    $fh = eval { $dhcpfile->open('>') } or die "Can't reopen dhcphosts file: $!";
    my $ret = 0;
    my $ff = 0;

    for (@content) {
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      if (/([0-9a-fA-F:]+),id:\*,set:client(\d+),([0-9.]+)/x) {
        #say "$_, MAC: $1, ID: $2, IP: $3";
        if ($2 == $v->{id}) {
          if (!$ff) {
            # replace same id
            if (!$v->{no_dhcp} and $v->{mac}) {
              print $fh "$v->{mac},id:*,set:client$v->{id},$v->{ip}\n";
              $ret = 1;
            } else {
              # delete line if no_dhcp flag is set
              $ret = 1;
            }
            $ff = 1;
          } else {
            # skip duplicate id line
            $self->rlog("Found duplicate ID in dhcphosts file, conflicting line deleted.");
            $ret = 1;
          }
        } elsif ($v->{mac} and $1 eq $v->{mac}) {
          $self->rlog("Found duplicate MAC in dhcphosts file, conflicting line deleted.");
          $ret = 1;
        } elsif ($3 eq $v->{ip}) {
          $self->rlog("Found duplicate IP in dhcphosts file, conflicting line deleted.");
          $ret = 1;
        } else {
          print $fh "$_\n"; # just copy other lines
        }
      } else {
        # invalid format - skipped
        $self->rlog("Found unparsable line in dhcphosts file, deleted.");
        $ret = 1;
      }
    }

    if (!$ff) { # if not found, add line
      if (!$v->{no_dhcp} and $v->{mac}) {
        print $fh "$v->{mac},id:*,set:client$v->{id},$v->{ip}\n";
        $ret = 1;
      }
    }
    $fh->close or die "Can't close dhcphosts file: $!";

    return $ret;
  });


  # my $resp = dhcp_delete($id);
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error
  $app->helper(dhcp_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $fh = eval { $dhcpfile->open('<') } or die "Can't read dhcphosts file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close dhcphosts file: $!";

    $fh = eval { $dhcpfile->open('>') } or die "Can't reopen dhcphosts file: $!";
    my $ret = 0;

    for (@content) {
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      if (/set:client\Q$id\E,/x) {
        #say "Skipped line $_";
        $self->rlog("Found duplicate ID in dhcphosts file, conflicting line deleted.") if $ret;
        $ret = 1;
        next;
      }
      print $fh "$_\n";
    }

    $fh->close or die "Can't close dhcphosts file: $!";

    return $ret;
  });


  # my $resp = dhcp_create_full([{id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55:66',profile=>'gwtest1'}, ...]);
  # fully updates /var/r2d2/dhcphosts.clients file,
  # returns 1-need apply/0-not needed on success,
  #   dies with 'error string' on error,
  #   will check ip/mac/no_dhcp flag and skip line if not set.
  $app->helper(dhcp_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $dhcpfile = path($self->config('dhcphosts_file'));

    my $fh = eval { $dhcpfile->open('>') } or die "Can't create dhcphosts file: $!";
    # data
    for (@$va) {
      next if !$self->is_myprofile($_->{profile}); # skip clients from invalid profiles
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      print $fh "$_->{mac},id:*,set:client$_->{id},$_->{ip}\n" if !$_->{no_dhcp} && $_->{mac};
    }
    $fh->close or die "Can't close dhcphosts file: $!";

    # always need apply
    return 1;
  });


  # my $err = $app->dhcp_apply()
  # SIGHUP dnsmasq
  # returns 1-success, dies on error
  $app->helper(dhcp_apply => sub {
    my $self = shift;

    # compare boot_dhcphosts_file with dhcphosts_file and rewrite it
    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $bootdhcpfile = path($self->config('boot_dhcphosts_file'));
    if (-f $dhcpfile) {
      my $d = eval { $dhcpfile->slurp } // die "Can't read dhcphosts file: $!";
      my $d2 = undef;
      if (-f $bootdhcpfile) {
        $d2 = eval { $bootdhcpfile->slurp } // die "Can't read boot dhcphosts file: $!";
      }
      if (!defined($d2) or $d2 ne $d) {
        eval { $bootdhcpfile->spurt($d) } or die "Can't write boot dhcphosts file: $!";
        $self->log->debug('Boot dhcphosts file is updated.');
      }
    }

    my $pidfile;
    my $pid_re = $self->config('dnsmasq_pidfile_regexp');
    for (@{path($self->config('dnsmasq_pid_dir'))->list}) {
      if (/$pid_re/) {
         $pidfile = $_;
         last;
       }
    }
    die 'Dnsmasq pidfile is not found!' unless $pidfile;
    chomp(my $pid = $pidfile->slurp);
    die 'Dnsmasq pid is invalid!' unless $pid =~ /^\d+$/;

    #say "Dnsmasq PID: ".$pid;
    die "error sending hup signal to pid $pid!" if kill('HUP', $pid) != 1;
    return 1;
  });

}

1;
