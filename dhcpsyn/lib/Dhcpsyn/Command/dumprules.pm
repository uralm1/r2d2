package Dhcpsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump reservedip lists from dhcpservers';
has usage => "Usage: APPLICATION dumprules [dhcpserver_ip]\n";

sub run {
  my ($self, $opt) = @_;
  my $app = $self->app;

  my @dhcpservers_opts;
  if ($opt) {
    for (@{$app->config('dhcpservers')}) {
      if ($opt eq $_) { push @dhcpservers_opts, $opt; last; }
    }
    unless (scalar @dhcpservers_opts) {
      $app->log->error("Invalid parameter: $opt (not in dhcpservers config option)");
      return 1;
    }
  } else {
    @dhcpservers_opts = @{$app->config('dhcpservers')};
  }

  for my $dhcpserver (@dhcpservers_opts) {
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
