use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Test::Files;
use Mojo::File qw(path);

diag "need some files to test...";
my $fh = undef;
my $testdir = path('/tmp', 'r2d2test')->make_path;
while (<DATA>) {
  last if /^__END__$/;
  if (/^@@ *(\S+)$/) {
    diag "prepare file $1";
    $fh->close if $fh;
    $fh = path($testdir, $1)->open('>');
    next;
  }
  print $fh $_ if $fh;
}
$fh->close if $fh;


note "common usage";
my $test_f = path($testdir, 'dhcphosts.clients1');
my $t = Test::Mojo->new('Gwsyn', {dhcphosts_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->dhcp_delete(12), 1, 'dhcp_delete1 12');
is($t->app->dhcp_delete(11), 1, 'dhcp_delete1 11');
is($t->app->dhcp_delete(11), 0, 'dhcp_delete1 11 non existent');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

note "delete last";
$test_f = path($testdir, 'dhcphosts.clients2');
$t = Test::Mojo->new('Gwsyn', {dhcphosts_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->dhcp_delete(13), 1, 'dhcp_delete2 13');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

note "delete all and intersecting ids: 1 and 11";
$test_f = path($testdir, 'dhcphosts.clients3');
$t = Test::Mojo->new('Gwsyn', {dhcphosts_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->dhcp_delete(1), 0, 'dhcp_delete3 1 non existent');
is($t->app->dhcp_delete(11), 1, 'dhcp_delete3 11');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

note "delete duplicating ids, issue warnings";
$test_f = path($testdir, 'dhcphosts.clients4');
$t = Test::Mojo->new('Gwsyn', {dhcphosts_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->dhcp_delete(11), 1, 'dhcp_delete4 11 with duplicating id');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
undef $t;

done_testing();

__DATA__
@@ dhcphosts.clients1
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
@@ result1
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
@@ dhcphosts.clients2
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
@@ result2
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
@@ dhcphosts.clients3
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
@@ result3
@@ dhcphosts.clients4
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:61,id:*,set:client11,1.2.3.41
11:22:33:44:55:62,id:*,set:client11,1.2.3.42
11:22:33:44:55:63,id:*,set:client11,1.2.3.43
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
@@ result4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
__END__
