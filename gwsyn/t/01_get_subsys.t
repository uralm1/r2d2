use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';

my $t = Test::Mojo->new('Gwsyn',{rlog_local=>1, rlog_remote=>0, disable_autoload=>1,
  dhcphosts_file=>'/tmp/r2d2test/dhcphosts.clients',
  firewall_file=>'/tmp/r2d2test/firewall.clients',
  tc_file=>'/tmp/r2d2test/traf.clients',
  my_profiles=>['gwtest1'],
  worker_db_file=>'/tmp/test$$.dat',
});

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^gwsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^gwsyn/)
  ->json_has('/version')
  ->json_has('/profiles');

done_testing();
