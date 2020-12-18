package Gwsyn::Plugin::Dhcp_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $resp = dhcp_add_replace({id=>11, ip=>'1.2.3.4', mac=>'11:22:33:44:55'});
  # returns 'ADDED'/'REPLACED' on success,
  #   dies with 'error string' on error
  $app->helper(dhcp_add_replace => sub {
    my ($self, $v) = @_;
    croak 'Bad argument' unless $v;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $fh = $dhcpfile->open('<');
    if (defined $fh) {
      print while <$fh>;
      $fh->close;
      return 0;
    } else {
      $app->log->error("Can't read dhcphosts file: $!");
      return 1;
    }

  });


  # my $resp = dhcp_delete($id);
  # returns 'NONE'/'DELETED' on success,
  #   dies with 'error string' on error
  $app->helper(dhcp_delete => sub {
    my ($self, $id) = @_;
    croak 'Bad argument' unless defined $id;

    my $dhcpfile = path($self->config('dhcphosts_file'));
    my $fh = $dhcpfile->open('<') or croak "Can't read dhcphosts file: $!";
    chomp(my @content = <$fh>);
    $fh->close;

    my $ret = 'NONE';
    $fh = $dhcpfile->open('>') or croak "Can't reopen dhcphosts file: $!";
    for (@content) {
      # 11:22:33:44:55:66,id:*,set:client123,192.168.33.22
      if (/set:client\Q$id\E/x) {
        say "Skipped line $_";
        $ret = 'DELETED';
        next;
      }
      print $fh "$_\n";
    }
    $fh->close;

    return $ret;
  });

}

1;
