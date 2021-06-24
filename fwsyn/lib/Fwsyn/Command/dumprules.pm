package Fwsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump iptables clients filter and mangle rules';
has usage => "Usage: APPLICATION dumprules [filter in|filter out|mangle in|mangle out]\n";

sub run {
  my ($self, @opt) = @_;
  my $opt = join ' ', @opt;
  my $app = $self->app;

  my $c = {
    'filter in' => 'f_in',
    'filter out' => 'f_out',
    'mangle in' => 'm_in',
    'mangle out' => 'm_out'
  };
  my @config_opts;
  if ($opt) {
    if ($c->{$opt}) {
      push @config_opts, $c->{$opt};
    } else {
      $app->log->error("Invalid parameter: $opt");
      return 1;
    }
  } else {
    push @config_opts, $c->{$_} for ('filter in', 'filter out', 'mangle in', 'mangle out');
  }

  for my $n (@config_opts) {
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
