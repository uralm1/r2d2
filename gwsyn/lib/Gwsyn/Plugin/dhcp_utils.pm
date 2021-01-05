package Gwsyn::Plugin::dhcp_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $resp = dhcp_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55'});
  # returns 'NONE'/'ADDED'/'REPLACED'/'DELETED' on success,
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
    my $ff = 0;
    my $ret = 'NONE';
    for (@content) {
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      if (/([0-9a-fA-F:]+),id:\*,set:client(\d+),([0-9.]+)/x) {
        #say "$_, MAC: $1, ID: $2, IP: $3";
        if ($2 == $v->{id}) {
          # replace same id
          if (!$v->{no_dhcp} and $v->{mac}) {
            print $fh "$v->{mac},id:*,set:client$v->{id},$v->{ip}\n";
            $ret = 'REPLACED';
          } else {
            # delete line if no_dhcp flag is set
            $ret = 'DELETED';
          }
          $ff = 1;
        } elsif ($v->{mac} and $1 eq $v->{mac}) {
          $self->rlog("Found duplicate MAC in dhcphosts file, conflicting line deleted.");
        } elsif ($3 eq $v->{ip}) {
          $self->rlog("Found duplicate IP in dhcphosts file, conflicting line deleted.");
        } else {
          print $fh "$_\n";
        }
      } else {
        # invalid format - skipped
        $self->rlog("Found unparsable line in dhcphosts file, deleted.");
      }
    }
    if (!$ff) { # if not found, add line
      if ($v->{mac}) {
        print $fh "$v->{mac},id:*,set:client$v->{id},$v->{ip}\n";
        $ret = 'ADDED';
      }
    }
    $fh->close or die "Can't close dhcphosts file: $!";

    return $ret;
  });


  # my $resp = dhcp_delete($id);
  # returns 'NONE'/'DELETED' on success,
  #   dies with 'error string' on error
  $app->helper(dhcp_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $fh = eval { $dhcpfile->open('<') } or die "Can't read dhcphosts file: $!";
    chomp(my @content = <$fh>);
    $fh->close or die "Can't close dhcphosts file: $!";

    my $ret = 'NONE';
    $fh = eval { $dhcpfile->open('>') } or die "Can't reopen dhcphosts file: $!";
    for (@content) {
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      if (/set:client\Q$id\E/x) {
        #say "Skipped line $_";
        $ret = 'DELETED';
        next;
      }
      print $fh "$_\n";
    }
    $fh->close or die "Can't close dhcphosts file: $!";

    return $ret;
  });


  # my $resp = dhcp_create_full([{id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55'}, ...]);
  # fully updates /var/r2d2/dhcphosts.clients file,
  # returns 1 on success,
  #   dies with 'error string' on error,
  #   will check ip/mac/no_dhcp flag and skip line if not set.
  $app->helper(dhcp_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $prof = $self->config('my_profile');

    my $fh = eval { $dhcpfile->open('>') } or die "Can't create dhcphosts file: $!";
    # data
    for (@$va) {
      next if ($_->{profile} ne $prof); # skip clients from invalid profiles
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      print $fh "$_->{mac},id:*,set:client$_->{id},$_->{ip}\n" if !$_->{no_dhcp} && $_->{mac};
    }
    $fh->close or die "Can't close dhcphosts file: $!";

    return 1;
  });


  # my $err = $app->dhcp_apply()
  # SIGHUP dnsmasq
  # returns 1-success, dies on error
  $app->helper(dhcp_apply => sub {
    my $self = shift;
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
