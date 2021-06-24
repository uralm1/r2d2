package Rtsyn::Command::dumpfiles;
use Mojo::Base 'Mojolicious::Command';

use Mojo::File qw(path);
#use Carp;

has description => '* Dump firewall rulefile';
has usage => "Usage: APPLICATION dumpfiles [firewall]\n";

sub run {
  my ($self, $opt) = @_;
  my $app = $self->app;

  my $c = {
    firewall => 'firewall_file'
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
    push @config_opts, $c->{$_} for (qw/firewall/);
  }

  for (@config_opts) {
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
