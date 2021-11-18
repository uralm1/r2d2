package Head::Ural::Dblog;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
#use Mojo::IOLoop;

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

# add record to operations log
# $obj->l(info=>"some log text", [subsys=>'head', sync=>1]);
# asyncronious by default
sub l {
  my $self = shift;
  my $logdata = {@_};

  my $subsys = $logdata->{subsys} // $self->{subsys};
  my $sync = $logdata->{sync} // 0;
  croak 'Parameter missing' unless (defined $subsys);

  $logdata->{info} = 'н/д' unless $logdata->{info};
  $subsys = 'н/д' unless $subsys;
  my $sql = 'INSERT INTO op_log (date, subsys, info) VALUES (NOW(), ?, ?)';
  if ($sync) {
    my $e = eval { $self->{mysql}->db->query($sql, $subsys, $logdata->{info}) };
    carp "Log record ($subsys) hasn't been inserted." unless defined $e;

  } else {
    $self->{mysql}->db->query($sql, $subsys, $logdata->{info} =>
      sub {
        my ($db, $err, $result) = @_;
        carp "Log record ($subsys) hasn't been inserted." if $err;
      }
    );
  }
}


# $obj->info("some log text", [subsys=>'head', sync=>1])
sub info {
  my $self = shift;
  $self->l(info=>shift, @_);
}

# $obj->warn("some log text", [subsys=>'head', sync=>1])
sub warn {
  my $self = shift;
  $self->l(info=>shift, @_);
}

# $obj->error("some log text", [subsys=>'head', sync=>1])
sub error {
  my $self = shift;
  $self->l(info=>shift, @_);
}

# $obj->debug("some log text", [subsys=>'head', sync=>1])
sub debug {
  my $self = shift;
  $self->l(info=>shift, @_);
}


# add record to audit log
# $obj->audit("some operation text", [login=>'testuser', sync=>1]);
# asyncronious by default
sub audit {
  my $self = shift;
  my $info = shift // 'н/д';
  my $logdata = {@_};

  my $sync = $logdata->{sync} // 0;
  my $login = $logdata->{login} // 'неизвестно';
  my $sql = 'INSERT INTO audit_log (date, login, info) VALUES (NOW(), ?, ?)';
  if ($sync) {
    my $e = eval { $self->{mysql}->db->query($sql, $login, $info) };
    carp "Audit log record hasn't been inserted." unless defined $e;

  } else {
    $self->{mysql}->db->query($sql, $login, $info =>
      sub {
        my ($db, $err, $result) = @_;
        carp "Audit log record hasn't been inserted." if $err;
      }
    );
  }
}


1;
