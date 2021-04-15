package Head::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::mysql;
use Head::Ural::Dblog;
use Head::Ural::CompatChk;

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
}

1;
__END__
