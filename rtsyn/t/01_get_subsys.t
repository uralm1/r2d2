use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Rtsyn',{rlog_local=>1, rlog_remote=>0, disable_autoload=>1,
  firewall_file=>'/tmp/r2d2test/firewall-rtsyn.clients',
});

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^rtsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^rtsyn/)
  ->json_has('/version')
  ->json_has('/profiles');

done_testing();
