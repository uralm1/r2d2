package Head::Ural::CompatChk;
use Mojo::Base -base;

use Carp;
use Storable;
use Mojo::mysql;
#use Mojo::IOLoop;

# constructor
# Ural::CompatChk->load($app);
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
    die "Compat file can not be read!\n" unless $self->{earlydb};

  } else {
    my $ref = $self->{earlydb} = {};
    $app->mysql_inet->db->query_p("SELECT id, profile FROM clients")->then(sub {
      my $results = shift;
      while (my $next = $results->hash) {
        $ref->{$next->{id}} = $next->{profile};
      }
      # save to file
      if ($file_name) {
        store($ref, $file_name) or
          $app->log->error("Can not create compat file $file_name!");
      }
      #say 'read db and store finished!';
    })->catch(sub {
      my $err = shift;
      die "Database error: $err\n";
    })->wait;

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

  # get actual db
  $self->{app}->mysql_inet->db->query_p("SELECT id, profile FROM clients")->then(sub {
    my $results = shift;
    my $ref = $self->{actdb} = {};
    while (my $next = $results->hash) {
      $ref->{$next->{id}} = $next->{profile};
    }
    while (my ($id, $p) = CORE::each %{$self->{earlydb}}) {
      $cb->($id, $p) unless exists $ref->{$id};
    }
  })->catch(sub {
    my $err = shift;
    $self->{app}->log->error('Client refresh: database operation error.');
    #die "Database error: $err\n";
  })->wait;
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
