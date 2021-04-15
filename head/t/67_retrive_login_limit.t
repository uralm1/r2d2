use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Head::Ural::NotifyClient qw(retrive_login_limit);

plan skip_all => 'Set TEST_CONF_DB=1 variable to enable online test' unless $ENV{TEST_CONF_DB};

my $t = Test::Mojo->new('Head');

my $s = eval { retrive_login_limit($t->app, 1) };
ok($s, 'retrive client id=1');
is($s->{login}, 'abdubakievadh', 'login client id=1');
diag $s->{limit_in_mb};
ok($s->{limit_in_mb}, 'limit_in_mb client id=1');

$s = eval {retrive_login_limit($t->app, 999) };
is($s, undef, 'retrive client id=999');
diag $@ unless $s;

done_testing();
