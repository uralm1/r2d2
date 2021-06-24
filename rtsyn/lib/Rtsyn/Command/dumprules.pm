package Rtsyn::Command::dumprules;
use Mojo::Base 'Mojolicious::Command';

#use Carp;

has description => '* Dump iptables clients mangle rules';
has usage => "Usage: APPLICATION dumprules [mangle out]\n";

sub run {
  my ($self, @opt) = @_;
  my $opt = join ' ', @opt;
  my $app = $self->app;

  my $c = {
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
    push @config_opts, $c->{$_} for ('mangle out');
  }

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
