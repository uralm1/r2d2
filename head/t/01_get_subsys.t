use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Head');
$t->get_ok('/subsys')->status_is(200)->content_like(qr/^head/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^head/)
  ->json_has('/version');

done_testing();
