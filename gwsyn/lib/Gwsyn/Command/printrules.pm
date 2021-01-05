package Gwsyn::Command::printrules;
use Mojo::Base 'Mojolicious::Command';

use Mojo::File qw(path);
#use Carp;

has description => '* Print firewall and traffic rules';
has usage => "Usage: APPLICATION printrules\n";

sub run {
  my $self = shift;
  my $app = $self->app;

  my $fwfile = path($app->config('firewall_file'));
  my $fh = eval { $fwfile->open('<') };
  if (defined $fh) {
    say '** DUMP of '.$fwfile->basename." **\n";
    print while <$fh>;
    $fh->close;
    say "\n** End of ".$fwfile->basename." DUMP **.\n";
  } else {
    $app->log->error("Can't read firewall file: $!");
  }

  my $tcfile = path($app->config('tc_file'));
  $fh = eval { $fwfile->open('<') };
  if (defined $fh) {
    say '** DUMP of '.$tcfile->basename." **\n";
    print while <$fh>;
    $fh->close;
    say "\n** End of ".$tcfile->basename." DUMP **.\n";
  } else {
    $app->log->error("Can't read tc file: $!");
    return 1;
  }

  return 0;
}

1;
