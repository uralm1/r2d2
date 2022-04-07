use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';
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


# my $t = $make_test->($test_mojo_file);
my $make_test = sub {
  my $tf = shift;
  return Test::Mojo->new('Fwsyn', { firewall_file => $tf->to_string,
    client_in_chain=>'pipe_in_inet_clients', client_out_chain=>'pipe_out_inet_clients',
    rlog_local=>1, rlog_remote=>0,
    my_profiles=>['plk'],
    worker_db_file=>'/tmp/test$$.dat',
  });
};

note "common usage";
my $test_f = path($testdir, 'firewall.clients1');
my $t = $make_test->($test_f);
is($t->app->fw_block(450, 2), 1, 'fw_block 450,2');
is($t->app->fw_block(451, 0), 1, 'fw_block 451,0 unblock');
is($t->app->fw_block(45, 0), 0, 'fw_block 45,0 non existent');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

#note "with newlines";
$test_f = path($testdir, 'firewall.clients2');
$t = $make_test->($test_f);
is($t->app->fw_block(450, 0), 1, 'fw_block2 450,0 unblock');
is($t->app->fw_block(451, 2), 1, 'fw_block2 451,2');
is($t->app->fw_block(452, 3), 1, 'fw_block2 452,3');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

#note "without rules";
$test_f = path($testdir, 'firewall.clients3');
$t = $make_test->($test_f);
is($t->app->fw_block(450, 2), 0, 'fw_block3 450,2');
is($t->app->fw_block(452, 0), 1, 'fw_block3 452,0 unblock');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

#note "without commit";
$test_f = path($testdir, 'firewall.clients4');
$t = $make_test->($test_f);
is($t->app->fw_block(450, 3), 0, 'fw_block4 450,3');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
undef $t;

#note "intersecting ids: 45 and 450";
$test_f = path($testdir, 'firewall.clients5');
$t = $make_test->($test_f);
is($t->app->fw_block(45, 3), 0, 'fw_block5 45,3 non existent');
is($t->app->fw_block(450,3), 1, 'fw_block5 450,3');
compare_ok($test_f, path($testdir, 'result5'), 'compare results 5');
undef $t;

#note "duplicate ids, issue warnings";
$test_f = path($testdir, 'firewall.clients6');
$t = $make_test->($test_f);
is($t->app->fw_block(450,2), 1, 'fw_block6 450,2 duplicate ids, issue warnings');
compare_ok($test_f, path($testdir, 'result6'), 'compare results 6');
undef $t;

done_testing();

__DATA__
@@ firewall.clients1
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
:ICMP_ONLY - [0:0]
:HTTP_ICMP - [0:0]
:HTTP_IM_ICMP - [0:0]
-A ICMP_ONLY -p icmp -j ACCEPT
-A HTTP_ICMP -p icmp -j ACCEPT
-A HTTP_ICMP -p tcp -m multiport --source-ports 80,8080,81,3128,443 -j ACCEPT
-A HTTP_ICMP -p tcp -m multiport --destination-ports 80,8080,81,3128,443 -j ACCEPT
-A HTTP_IM_ICMP -p icmp -j ACCEPT
-A HTTP_IM_ICMP -p tcp -j HTTP_ICMP
-A HTTP_IM_ICMP -p tcp -m multiport --source-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT
-A HTTP_IM_ICMP -p tcp -m multiport --destination-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
# 450
#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
#-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 3
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 3
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result1
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
:ICMP_ONLY - [0:0]
:HTTP_ICMP - [0:0]
:HTTP_IM_ICMP - [0:0]
-A ICMP_ONLY -p icmp -j ACCEPT
-A HTTP_ICMP -p icmp -j ACCEPT
-A HTTP_ICMP -p tcp -m multiport --source-ports 80,8080,81,3128,443 -j ACCEPT
-A HTTP_ICMP -p tcp -m multiport --destination-ports 80,8080,81,3128,443 -j ACCEPT
-A HTTP_IM_ICMP -p icmp -j ACCEPT
-A HTTP_IM_ICMP -p tcp -j HTTP_ICMP
-A HTTP_IM_ICMP -p tcp -m multiport --source-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT
-A HTTP_IM_ICMP -p tcp -m multiport --destination-ports 25,110,995,143,993,119,563,5190,5222,5223,1863 -j ACCEPT

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 2
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 2
# 451
#-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
#-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ firewall.clients2
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:ICMP_ONLY - [0:0]
-A ICMP_ONLY -p icmp -j ACCEPT
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT

# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT

COMMIT

*mangle
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 3
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 3
# 451
#-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
#-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451

# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j MARK --set-mark 2
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -j MARK --set-mark 2
COMMIT
@@ result2
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:ICMP_ONLY - [0:0]
-A ICMP_ONLY -p icmp -j ACCEPT
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT

# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT

COMMIT

*mangle
# 450
#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
#-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 2
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j MARK --set-mark 2
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j MARK --set-mark 3
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -j MARK --set-mark 3
COMMIT
@@ firewall.clients3
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
COMMIT
*mangle
# 450
# 451
# 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result3
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
COMMIT
*mangle
# 450
# 451
# 452
#-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ firewall.clients4
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
*mangle
# 450
@@ result4
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
*mangle
# 450
COMMIT
@@ firewall.clients5
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
COMMIT
*mangle
# 450
#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
COMMIT
@@ result5
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
COMMIT
*mangle
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 3
COMMIT
@@ firewall.clients6
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
# 450
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
#-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
#-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 450
#-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450
#-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451
# 452
#-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
#-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result6
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
# 450
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 2
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -j MARK --set-mark 2
# 450
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450 -j MARK --set-mark 2
# 452
#-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
#-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
__END__
