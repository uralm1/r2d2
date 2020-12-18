package Gwsyn::Command::printdhcp;
use Mojo::Base 'Mojolicious::Command';

use Mojo::File qw(path);
use Carp;

has description => '* Print dhcp hosts reservations';
has usage => "Usage: APPLICATION printdhcp\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $dhcpfile = path($app->config('dhcphosts_file'));
  my $fh = $dhcpfile->open('<');
  if (defined $fh) {
    print while <$fh>;
    $fh->close;
    return 0;
  } else {
    $app->log->error("Can't read dhcphosts file: $!");
    return 1;
  }
}

1;
