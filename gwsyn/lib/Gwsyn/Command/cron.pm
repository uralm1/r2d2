package Gwsyn::Command::cron;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::IOLoop;
use Mojo::Log;
#use Algorithm::Cron;

has description => '* Run builtin internal scheduler /REQUIRED/';
has usage => "Usage: APPLICATION cron\n";

sub run {
  my $self = shift;
  my $app = $self->app;
  my $log = $app->log;

  say "NOT IMPLEMENTED";
  $app->rlog("test1");
  $app->rlog("test2");
  $app->rlog("test3");

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


#-------------------------------------------------

1;
