use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Head::Ural::NotifyClient qw(retrive_ad_fullname_email);

plan skip_all => 'Set TEST_CONF_DB=1 variable to enable online test' unless $ENV{TEST_CONF_DB};

my $t = Test::Mojo->new('Head');

my $s = eval { retrive_ad_fullname_email($t->app, 'abdubakievadh') };
ok($s, 'retrive client abdubakievadh');
diag $s->{fullname};
ok($s->{fullname}, 'fullname');
is($s->{email}, 'abdubakievadh@uwc.ufanet.ru', 'email');

$s = eval {retrive_ad_fullname_email($t->app, 'abrvalg') };
is($s, undef, 'retrive client abrvalg');
diag $@ unless $s;

done_testing();
