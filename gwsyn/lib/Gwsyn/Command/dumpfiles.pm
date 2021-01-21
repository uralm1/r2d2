package Gwsyn::Command::dumpfiles;
use Mojo::Base 'Mojolicious::Command';

use Mojo::File qw(path);
#use Carp;

has description => '* Dump firewall, traffic, dhcp rulefiles';
has usage => "Usage: APPLICATION dumpfiles\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  for (qw/firewall_file tc_file dhcphosts_file/) {
    my $fobj = path($app->config($_));
    my $fh = eval { $fobj->open('<') };
    if ($fh) {
      say '** DUMP of '.$fobj->basename." **";
      while (my $l = <$fh>) { print $l };
      $fh->close;
      say "** End of ".$fobj->basename." dump **.\n";
    } else {
      $app->log->error("Error reading $_: $!");
    }
  }
  return 0;
}

1;
