use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Dhcpsyn',{rlog_local=>1, rlog_remote=>0, disable_autoload=>1,
});

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^dhcpsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^dhcpsyn/)
  ->json_has('/version')
  ->json_has('/profile');

done_testing();
