package Gwsyn::Plugin::ipt_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $resp = fwrules_create_full([{id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55', defjump=>'ACCEPT'}, ...]);
  # fully updates /var/r2d2/firewall.clients,
  # returns 1 on success,
  #   dies with 'error string' on error,
  #   will check mac and add line without it if not set.
  $app->helper(fwrules_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $fwfile = path($self->config('firewall_file'));
    my $client_in_chain = $self->config('client_in_chain');
    my $client_out_chain = $self->config('client_out_chain');

    my $fh = $fwfile->open('>') or die "Can't create firewall file: $!";

    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
    print $fh "*filter\n";
    print $fh ":$client_in_chain - [0:0]\n";
    print $fh ":$client_out_chain - [0:0]\n";
    print $fh ":ICMP_ONLY - [0:0]\n";
    print $fh ":HTTP_ICMP - [0:0]\n";
    print $fh ":HTTP_IP_ICMP - [0:0]\n";
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
      print $fh "# $_->{id}\n";
      print $fh "-A $client_in_chain -d $_->{ip} -j $_->{defjump}\n";
      my $m = ($_->{mac}) ? "-m mac --mac-source $_->{mac} " : '';
      print $fh "-A $client_out_chain -s $_->{ip} ${m}-j $_->{defjump}\n";
      $mangle_append .= "# $_->{id}\n";
      $mangle_append .= "-A $client_in_chain -d $_->{ip}\n";
      $mangle_append .= "-A $client_out_chain -s $_->{ip}\n";
    }
    print $fh "COMMIT\n\n";
    print $fh "*mangle\n";
    print $fh ":$client_in_chain - [0:0]\n";
    print $fh ":$client_out_chain - [0:0]\n";
    print $fh $mangle_append;
    print $fh "COMMIT\n";

    $fh->close or die "Can't close firewall file: $!";

    return 1;
  });


  # my $err = $app->fwrules_apply()
  # returns 1-success, dies on error
  $app->helper(fwrules_apply => sub {
    my $self = shift;


  });

}

1;
