use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Ui');

my ($type, $hostname) = $t->app->split_agent_type();
ok($type eq '' && $hostname eq '', 'not defined');

($type, $hostname) = $t->app->split_agent_type('');
ok($type eq '' && $hostname eq '', 'empty string');

($type, $hostname) = $t->app->split_agent_type('asd');
ok($type eq 'asd' && $hostname eq '', 'asd');

($type, $hostname) = $t->app->split_agent_type('@fgh');
ok($type eq '' && $hostname eq '', '@fgh');

($type, $hostname) = $t->app->split_agent_type('asd@');
ok($type eq 'asd' && $hostname eq '', 'asd@');

($type, $hostname) = $t->app->split_agent_type('asd@fgh');
ok($type eq 'asd' && $hostname eq 'fgh', 'asd@fgh');

done_testing();
