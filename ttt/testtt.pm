package Head::Command::testtt;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::mysql;
use Head::Ural::Dblog;

has description => '* Testtt';
has usage => "Usage: APPLICATION testtt\n";

sub run {
  my $self = shift;
  my $app = $self->app;
  say "TEST START";

  # testing promises --------------------------------------------
  say "START FIRST OPERATION";
  $app->mysql_inet->db->query_p("SELECT sleep(3)")->then(sub {
      my @val = @_;
      say "SUCCESS1";
      #say $app->dumper(\@val);
      # $val[0] == Mojo::mysql::Results 1
    })->catch(sub {
      my @err = @_;
      say "ERROR1";
      #say $app->dumper(\@err);
    })->finally(sub {
      say "FINISHED FIRST OPERATION";
    })->then(sub {
      say "START SECOND OPERATION";
      return $app->mysql_inet->db->query_p("SELECT xsleep(3)");
    })->then(sub {
      my @val = @_;
      say "SUCCESS2";
      # say $app->dumper(\@val);
      # $val[0] == Mojo::mysql::Results 2
    })->catch(sub {
      my @err = @_;
      say "ERROR2";
    })->finally(sub {
      say "FINISHED SECOND OPERATION";
    })->wait;

  say "TEST FINISHED COMMAND FUNCTION";
  return 0;
}


1;
