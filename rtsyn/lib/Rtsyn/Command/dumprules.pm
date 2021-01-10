package Rtsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump iptables clients mangle rules';
has usage => "Usage: APPLICATION dumprules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  if (my $dump = $app->rt_dump) {
    say @$dump;
  } else {
    $app->log->error('Error dumping client rules.');
  }

  return 0;
}

1;
