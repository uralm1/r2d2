package Head::Command::testtt;
use Mojo::Base 'Mojolicious::Command';

use Carp;
use Mojo::mysql;
#use Head::Ural::Dblog;

has description => '* Testtt';
has usage => "Usage: APPLICATION testtt\n";

sub run {
  my $self = shift;
  my $app = $self->app;
  say "TEST START";

  my $j = {
    key1 => 'value1',
    key2 => 'value2',
    key3 => 'value3',
    key4 => 'value4',
    key5 => 'value5',
  };

  my $s = [ 0, 0 ];
  $self->_rrr($j, $s);

  say "TEST FINISHED COMMAND FUNCTION";
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  return 0;
}

sub _rrr {
  my ($self, $j, $s) = @_;
  my $app = $self->app;

  my ($k, $v);
  unless (($k, $v) = each %$j) {
    say "DONE total: $s->[0], updated: $s->[1]";
    return undef;
  }
  say "Update $k, $v";
  $s->[0]++;

  my $x = $k eq 'key4' ? 'x':'';
  $app->mysql_inet->db->query_p("SELECT ${x}sleep(3)")->then(sub {
    my $results = shift;
    say "SUCCESS";
    $s->[1] += $results->affected_rows;
    #say $app->dumper(\@val);
    # $val[0] == Mojo::mysql::Results 1
  })->finally(sub {
    say "FINISHED OPERATION";
  })->then(sub {
    my $rr = $self->_rrr($j, $s);
    #say "next returned ".$app->dumper($rr);
  })->catch(sub {
    my @err = @_;
    say "ERROR";
    return undef;
    #say $app->dumper(\@err);
  });
}


1;
