package Gwsyn::Command::printdhcp;
use Mojo::Base 'Mojolicious::Command';

use Mojo::File qw(path);
#use Carp;

has description => '* Print dhcp hosts reservations';
has usage => "Usage: APPLICATION printdhcp\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $dhcpfile = path($app->config('dhcphosts_file'));
  my $fh = eval { $dhcpfile->open('<') };
  if (defined $fh) {
    say '** DUMP of '.$dhcpfile->basename." **\n";
    print while <$fh>;
    $fh->close;
    say "\n** End of ".$dhcpfile->basename." DUMP **.\n";
  } else {
    $app->log->error("Can't read dhcphosts file: $!");
    return 1;
  }

  return 0;
}

1;
