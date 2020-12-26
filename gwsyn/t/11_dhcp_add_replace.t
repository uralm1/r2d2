use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Gwsyn');

ok($t->app->dhcp_add_replace({id=>123, ip=>'192.168.34.101', mac=>'11:22:33:44:55:66'}), 'dhcp_add_replace 1');

done_testing();
