use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';

my $t = Test::Mojo->new('Dhcpsyn',{rlog_local=>1, rlog_remote=>0, disable_autoload=>1,
  my_profiles=>['plk'],
  worker_db_file=>'/tmp/test$$.dat',
});

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^dhcpsyn/);
$t->get_ok('/subsys?_format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^dhcpsyn/)
  ->json_has('/version')
  ->json_has('/profiles');

done_testing();
