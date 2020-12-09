package Master::Command::testtt;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::mysql;
use Master::Ural::Dblog;

has description => '* Testtt';
has usage => "Usage: APPLICATION testtt\n";

sub run {
  my $self = shift;
  my $app = $self->app;
  say "TEST START";

=for comment
  # testing delay ----------------------------------------------
  Mojo::IOLoop->delay(
    sub {
      my $delay = shift;
      say "START FIRST OPERATION";
      $app->mysql_inet->db->query("SELECT sleep(3)" => $delay->begin);
    },
    sub {
      my ($delay, $err, $results) = @_;
      if ($err) { say "ERROR1"; } else { say "SUCCESS1"; }
      say "FINISHED FIRST OPERATION";

      $delay->pass;
    },
    sub {
      my $delay = shift;
      say "START SECOND OPERATION";
      $app->mysql_inet->db->query("SELECT sleep(3)" => $delay->begin);
    },
    sub {
      my ($delay, $err, $results) = @_;
      if ($err) { say "ERROR2"; } else { say "SUCCESS2"; }
      say "FINISHED SECOND OPERATION";

      say "TEST FINISHED LAST OPERATION";
    },
  );
=cut

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
    });

  say "TEST FINISHED COMMAND FUNCTION";
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  return 0;
}


1;
