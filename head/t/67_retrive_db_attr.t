use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Head::Ural::NotifyClient qw(retrive_db_attr);

plan skip_all => 'Set TEST_CONF_DB=1 variable to enable online test' unless $ENV{TEST_CONF_DB};

my $t = Test::Mojo->new('Head');

my $s = eval { retrive_db_attr($t->app, 1) };
ok($s, 'retrive client id=1');
is($s->{login}, 'abdubakievadh', 'login client id=1');
diag $s->{limit_in_mb};
ok($s->{limit_in_mb}, 'limit_in_mb client id=1');
ok(defined($s->{qs}) && $s->{qs} >= 0 && $s->{qs} <= 3, 'qs client id=1');
ok(defined($s->{notified}) && $s->{notified} >=0 && $s->{notified} <= 1, 'notified client id=1');

# new fields
#$s->{cn}
#$s->{email}
#$s->{device_name}

$s = eval {retrive_db_attr($t->app, 999) };
is($s, undef, 'retrive client id=999');
diag $@ unless $s;

done_testing();
