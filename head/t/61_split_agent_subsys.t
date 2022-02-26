use Mojo::Base -strict;

use Test::More;

use Head::Ural::Profiles qw(split_agent_subsys);


my ($type, $hostname) = split_agent_subsys();
ok($type eq '' && $hostname eq '', 'not defined');

($type, $hostname) = split_agent_subsys('');
ok($type eq '' && $hostname eq '', 'empty string');

($type, $hostname) = split_agent_subsys('asd');
ok($type eq 'asd' && $hostname eq '', 'asd');

($type, $hostname) = split_agent_subsys('@fgh');
ok($type eq '' && $hostname eq '', '@fgh');

($type, $hostname) = split_agent_subsys('asd@');
ok($type eq 'asd' && $hostname eq '', 'asd@');

($type, $hostname) = split_agent_subsys('asd@fgh');
ok($type eq 'asd' && $hostname eq 'fgh', 'asd@fgh');

done_testing();
