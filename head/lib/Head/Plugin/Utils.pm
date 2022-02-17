package Head::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::mysql;
use Head::Ural::Dblog;
use Head::Ural::CompatChk;
use Head::Ural::Profiles;
use Head::Ural::SyncQueue;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # database object
  $app->helper(mysql_inet => sub {
    state $mysql_inet = Mojo::mysql->strict_mode(shift->config('inet_db_conn'));
  });

  # dblog singleton
  $app->helper(dblog => sub {
    my $self = shift;
    state $dblog = Head::Ural::Dblog->new($self->mysql_inet, subsys => $self->app->defaults('subsys'));
  });

  # profiles singleton
  $app->helper(profiles => sub {
    state $profiles = Head::Ural::Profiles->new(@_);
  });

  # sync queue singleton
  $app->helper(syncqueue => sub {
    state $syncqueue = Head::Ural::SyncQueue->new(@_);
  });

  # del_compat_check singleton
  $app->helper(del_compat_check => sub {
    state $del_compat_check = Head::Ural::CompatChk->load(shift);
  });


  # my $bool = $self->check_workers
  $app->helper(check_workers => sub {
    my $self = shift;
    my $stats = $self->minion->stats;
    return ($stats->{active_workers} != 0 || $stats->{inactive_workers} != 0);
  });


  # $self->exists_and_number404($value)
  # renders error if not number
  $app->helper(exists_and_number404 => sub {
    my ($self, $v) = @_;
    unless (defined $v && $v =~ /^\d+$/) {
      $self->render(text => 'Bad parameter', status => 404);
      return undef;
    }
    return 1;
  });


  # my $json = $self->json_content($self->req)
  # renders error if not application/json or resulting json is undef or invalid
  $app->helper(json_content => sub {
    my ($self, $req) = @_;
    my $fmt = $req->headers->content_type;
    unless (defined $fmt && $fmt =~ m#^application/json$#i) {
      $self->render(text => 'Unsupported content', status => 503);
      return undef;
    }
    my $j = $req->json;
    unless ($j and (ref($j) eq 'HASH' or ref($j) eq 'ARRAY')) {
      $self->render(text => 'Bad json format', status => 503);
      return undef;
    }
    return $j;
  });

}

1;
__END__
