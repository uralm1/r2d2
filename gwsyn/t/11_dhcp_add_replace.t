use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Test::Files;
use Mojo::File qw(path);
use lib '../ljq/lib';

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


# my $t = $make_test->($test_mojo_file);
my $make_test = sub {
  my $tf = shift;
  return Test::Mojo->new('Gwsyn', { dhcphosts_file => $tf->to_string,
    rlog_local=>1, rlog_remote=>0,
    my_profiles=>['gwtest1'],
    worker_db_file=>'/tmp/test$$.dat',
  });
};

note "common usage";
my $test_f = path($testdir, 'dhcphosts.clients1');
my $t = $make_test->($test_f);
is($t->app->dhcp_add_replace({id=>12,ip=>'1.2.3.12',mac=>'44:44:44:44:44:44'}), 1, 'dhcp_add_replace1 12 replaced');
is($t->app->dhcp_add_replace({id=>11,ip=>'1.2.3.11',mac=>''}), 1, 'dhcp_add_replace1 11 removed no mac');
is($t->app->dhcp_add_replace({id=>13,ip=>'1.2.3.13',mac=>'55:55:55:55:55:55'}), 1, 'dhcp_add_replace1 13 replaced');
is($t->app->dhcp_add_replace({id=>14,ip=>'1.2.3.14',mac=>'66:66:66:66:66:66'}), 1, 'dhcp_add_replace1 14 added');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

note "removed last, added one and intersecting ids: 1 and 14";
$test_f = path($testdir, 'dhcphosts.clients2');
$t = $make_test->($test_f);
is($t->app->dhcp_add_replace({id=>11,ip=>'1.2.3.4',mac=>'11:11:11:11:11:11',no_dhcp=>1}), 1, 'dhcp_add_replace2 11 removed no_dhcp');
is($t->app->dhcp_add_replace({id=>14,ip=>'1.2.3.14',mac=>'66:66:66:66:66:66'}), 1, 'dhcp_add_replace2 14 added');
is($t->app->dhcp_add_replace({id=>1,ip=>'1.2.3.1',mac=>'11:11:11:11:11:11'}), 1, 'dhcp_add_replace2 1 added');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

note "some exotic perversions";
$test_f = path($testdir, 'dhcphosts.clients3');
$t = $make_test->($test_f);
is($t->app->dhcp_add_replace({id=>12,ip=>'1.2.3.12',mac=>'11:22:33:44:55:77'}), 1, 'dhcp_add_replace3 12 replaced');
is($t->app->dhcp_add_replace({id=>12,ip=>'1.2.3.12',mac=>'11:22:33:44:55:66'}), 1, 'dhcp_add_replace3 12 replaced and 11 deleted');
is($t->app->dhcp_add_replace({id=>12,ip=>'1.2.3.6',mac=>'11:22:33:44:55:77'}), 1, 'dhcp_add_replace3 12 replaced and 13 deleted');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

note "duplicate ids and warnings";
$test_f = path($testdir, 'dhcphosts.clients4');
$t = $make_test->($test_f);
is($t->app->dhcp_add_replace({id=>11,ip=>'1.2.3.12',mac=>'11:22:33:44:55:88'}), 1, 'dhcp_add_replace4 11 replaced, duplicates exists');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
undef $t;

done_testing();

__DATA__
@@ dhcphosts.clients1
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
@@ result1
44:44:44:44:44:44,id:*,set:client12,1.2.3.12
55:55:55:55:55:55,id:*,set:client13,1.2.3.13
66:66:66:66:66:66,id:*,set:client14,1.2.3.14
@@ dhcphosts.clients2
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
@@ result2
66:66:66:66:66:66,id:*,set:client14,1.2.3.14
11:11:11:11:11:11,id:*,set:client1,1.2.3.1
@@ dhcphosts.clients3
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
@@ result3
11:22:33:44:55:77,id:*,set:client12,1.2.3.6
@@ dhcphosts.clients4
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:61,id:*,set:client11,1.2.3.41
11:22:33:44:55:62,id:*,set:client11,1.2.3.42
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:71,id:*,set:client12,1.2.3.51
@@ result4
11:22:33:44:55:88,id:*,set:client11,1.2.3.12
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:71,id:*,set:client12,1.2.3.51
__END__
