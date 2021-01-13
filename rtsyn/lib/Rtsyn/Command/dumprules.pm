package Rtsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump iptables clients mangle rules';
has usage => "Usage: APPLICATION dumprules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $m = $app->rt_matang->{m_out};
  if (my $d = $m->{dump_sub}()) {
    say "** DUMP $m->{rule_desc} table $m->{table} **";
    say @$d;
    say '';
  } else {
    $app->log->error("Error dumping $m->{rule_desc} table $m->{table}.");
  }

  return 0;
}

1;
