use Mojo::Base -strict;

use Test::More;

use Head::Ural::Profiles qw(split_agent_type);


my ($type, $hostname) = split_agent_type();
ok($type eq '' && $hostname eq '', 'not defined');

($type, $hostname) = split_agent_type('');
ok($type eq '' && $hostname eq '', 'empty string');

($type, $hostname) = split_agent_type('asd');
ok($type eq 'asd' && $hostname eq '', 'asd');

($type, $hostname) = split_agent_type('@fgh');
ok($type eq '' && $hostname eq '', '@fgh');

($type, $hostname) = split_agent_type('asd@');
ok($type eq 'asd' && $hostname eq '', 'asd@');

($type, $hostname) = split_agent_type('asd@fgh');
ok($type eq 'asd' && $hostname eq 'fgh', 'asd@fgh');

done_testing();
