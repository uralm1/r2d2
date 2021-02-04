package Head::Ural::Dblog;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
use Mojo::IOLoop;

# Ural::Dblog->new($mysql, subsys=>'head');
sub new {
  my ($class, $mysql, %logdata) = @_;
  croak 'Database required' unless defined $mysql;
  my $self = bless {
    mysql => $mysql,
    subsys => undef,
  }, $class;
  $self->{subsys} = $logdata{subsys} if defined $logdata{subsys};
  #say 'Ural::Dblog constructor!';
  return $self;
}

# $obj->l([subsys=>'head',] info=>"some log text");
sub l {
  my $self = shift;
  my $logdata = {@_};

  my $subsys = (defined $logdata->{subsys}) ? $logdata->{subsys} : $self->{subsys};
  croak 'Parameter missing' unless (defined $subsys);

  $logdata->{info} = 'н/д' unless $logdata->{info};
  $subsys = 'н/д' unless $subsys;
  $self->{mysql}->db->query("INSERT INTO op_log \
(date, subsys, info) VALUES (NOW(), ?, ?)", $subsys, $logdata->{info} =>
    sub {
      my ($db, $err, $result) = @_;
      carp "Log record ($subsys) hasn't been inserted." if $err;
    }
  );
}


1;
