use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Head');
$t->get_ok('/ui/oplog')->status_is(400);
$t->get_ok('/ui/oplog?page=0')->status_is(400);
$t->get_ok('/ui/oplog?lop=0')->status_is(400);
$t->get_ok('/ui/oplog?page=1&lop=0')->status_is(400);
$t->get_ok('/ui/oplog?page=asd&lop=10')->status_is(400);
$t->get_ok('/ui/oplog?page=1&lop=asd')->status_is(400);
$t->get_ok('/ui/oplog?page=1&lop=501')->status_is(400);

$t->get_ok('/ui/oplog?page=1&lop=10')->status_is(200)
  ->json_is('/page' => 1)
  ->json_has('/pages')
  ->json_is('/lines_on_page' => 10)
  ->json_has('/lines_total')
  ->json_has('/d');

done_testing();
