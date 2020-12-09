package Master::Ural::Dblog;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
use Mojo::IOLoop;

# Ural::Dblog->new($db, subsys=>'master');
sub new {
  my ($class, $db, %logdata) = @_;
  croak 'Database required' unless defined $db;
  my $self = bless {
    db => $db,
    subsys => undef,
  }, $class;
  $self->{subsys} = $logdata{subsys} if defined $logdata{subsys};
  return $self;
}

# $obj->l([subsys=>'master',] info=>"some log text");
sub l {
  my $self = shift;
  my $logdata = {@_};

  my $subsys = (defined $logdata->{subsys}) ? $logdata->{subsys} : $self->{subsys};
  croak 'Parameter missing' unless (defined $subsys);

  $logdata->{info} = 'н/д' unless $logdata->{info};
  $subsys = 'н/д' unless $subsys;
  $self->{db}->query("INSERT INTO op_log \
    (date, subsys, info) VALUES (NOW(), ?, ?)",
    $subsys, $logdata->{info} =>
    sub {
      my ($db, $err, $result) = @_;
      carp "Log record ($subsys) hasn't been inserted." if $err;
    }
  );
  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}


1;
