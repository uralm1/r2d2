use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Gwsyn');

ok($t->app->dhcp_delete(452), 'dhcp_delete 1');

done_testing();
