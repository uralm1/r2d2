use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';

my $t = Test::Mojo->new('Fwsyn',{rlog_local=>1, rlog_remote=>0, disable_autoload=>1,
  firewall_file=>'/tmp/r2d2test/firewall.clients',
  tc_file=>'/tmp/r2d2test/traf.clients',
  my_profiles=>['plk'],
  worker_db_file=>'/tmp/test$$.dat',
});

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^fwsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^fwsyn/)
  ->json_has('/version')
  ->json_has('/profiles');

done_testing();
