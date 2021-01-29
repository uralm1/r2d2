package Dhcpsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump reservedip lists from dhcpservers';
has usage => "Usage: APPLICATION dumprules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  for my $dhcpserver (@{$app->config('dhcpservers')}) {
    my $m = $app->dhcp_matang->{win_dhcp};

    if (my $d = $m->{dump_sub}($dhcpserver)) {
      say "** DUMP dhcpserver $dhcpserver $m->{rule_desc} **";
      for (@$d) {
        if ($_ =~ $m->{re2}($dhcpserver)) {
          print $_;
        }
      }
      say '';

    } else {
      $app->log->error("Error dumping $m->{rule_desc} dhcpserver $dhcpserver.");
    }
  }

  return 0;
}

1;
