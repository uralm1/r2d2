package Rtsyn::Command::loadrules;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Reload all rules from head like on restart';
has usage => "Usage: APPLICATION loadrules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  $app->log->info('Reloading rules configuration');
  unless (eval { $app->load_rules }) {
    $app->log->error("Loading rules failed: $@");
    return 1;
  }

  return 0;
}

1;
