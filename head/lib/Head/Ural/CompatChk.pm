package Head::Ural::CompatChk;
use Mojo::Base -base;

use Carp;
use Storable;
use Mojo::mysql;
#use Mojo::IOLoop;

# constructor
# Ural::CompatChk->load($app);
# returns undef on failure
sub load {
  my ($class, $app) = @_;
  croak "App parameter required!" unless $app;
  my $self = bless {
    app => $app,
    file_name => '',
    actdb => undef,
    earlydb => undef
  }, $class;
  #say 'Ural::CompatChk constructor!';

  my $file_name = $app->config('checkdel_compat_file');
  $self->{file_name} = $file_name;
  if ($file_name and -r $file_name) {
    $self->{earlydb} = retrieve($file_name);
    unless ($self->{earlydb}) {
      $app->log->error('Compat file can not be read!');
      return undef;
    }

  } else {
    my $ref = $self->{earlydb} = {};
    my $e = eval {
      my $results = $app->mysql_inet->db->query("SELECT id, profile FROM clients");
      while (my $next = $results->hash) {
        $ref->{$next->{id}} = $next->{profile};
      }
      1;
    };
    unless (defined $e) {
      $app->log->error("Database error: $@");
      return undef;
    }

    # save to file
    if ($file_name) {
      store($ref, $file_name) or
        $app->log->error("Can not create compat file $file_name!");
    }
    #say 'read db and store finished!';
  }
  #say 'Ural::CompatChk constructor finished!';

  return $self;
}


sub dump {
  my $self = shift;
  croak "Uninitialized!" unless $self->{earlydb};
  $self->each(sub { my ($id, $p) = @_; say "$id => $p" });
  return $self;
}


# $obj->each(sub { my ($id, $profile) = @_; say "$id => $profile" });
sub each {
  my ($self, $cb) = @_;
  while (my @e = CORE::each %{$self->{earlydb}}) { $cb->(@e) }
  return $self;
}


# $obj->eachdel(sub { my ($id, $profile) = @_; say "$id => $profile has beed removed" });
sub eachdel {
  my ($self, $cb) = @_;
  croak "Uninitialized!" unless $self->{earlydb};

  my $ref = $self->{actdb} = {};
  my $e = eval {
    # get actual db
    my $results = $self->{app}->mysql_inet->db->query("SELECT id, profile FROM clients");
    while (my $next = $results->hash) {
      $ref->{$next->{id}} = $next->{profile};
    }
    1;
  };
  # do not invoke update callbacks in case of errors!
  if (defined $e) {
    while (my ($id, $p) = CORE::each %{$self->{earlydb}}) {
      $cb->($id, $p) unless exists $ref->{$id};
    }
  } else {
    $self->{app}->log->error('Client refresh: database operation error.');
    #die "Database error: $@\n";
  }

  return $self;
}


sub update {
  my $self = shift;
  croak "Can update only after eachdel!" unless $self->{actdb};
  $self->{earlydb} = $self->{actdb};
  $self->{actdb} = undef;
  if ($self->{file_name}) {
    store($self->{earlydb}, $self->{file_name}) or
      $self->{app}->log->error("Can not create compat file $self->{file_name}!");
  }
  return $self;
}


# unless ($obj->exists($id)) { say "$id" }
#sub exists {
#  my ($self, $id) = @_;
#  return exists $self->{earlydb}->{$id};
#}


1;
