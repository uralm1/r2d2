package Fwsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump iptables clients filter and mangle rules';
has usage => "Usage: APPLICATION dumprules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  for my $n (qw/f_in f_out m_in m_out/) {
    my $m = $app->fw_matang;
    if (my $d = $m->{$n}{dump_sub}()) {
      say "** DUMP $m->{$n}{rule_desc} table $m->{$n}{table} **";
      say @$d;
    } else {
      $app->log->error("Error dumping $m->{$n}{rule_desc} table $m->{$n}{table}.");
    }
  }

  return 0;
}

1;
