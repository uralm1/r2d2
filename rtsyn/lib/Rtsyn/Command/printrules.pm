package Rtsyn::Command::printrules;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Print iptables rules';
has usage => "Usage: APPLICATION printrules\n";

sub run {
  my $self = shift;
  my $app = $self->app;
  
  my $dump = $app->rt_get_dump;
  if ($dump) {
    say @$dump;
  } else {
    $app->log->error('Error dumping rules.');
  }

  return 0;
}

1;
