use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Gwsyn');

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^gwsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^gwsyn/)
  ->json_has('/version')
  ->json_has('/profile');

done_testing();
