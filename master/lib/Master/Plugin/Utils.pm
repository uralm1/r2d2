package Master::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::mysql;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # database object
  $app->helper(mysql_inet => sub {
    state $mysql_inet = Mojo::mysql->strict_mode(shift->config('inet_db_conn'));
  });

}

1;
__END__
