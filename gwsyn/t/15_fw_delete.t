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
my $test_f = path($testdir, 'firewall.clients1');
my $t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(451), 1, 'fw_delete1 451');
is($t->app->fw_delete(452), 1, 'fw_delete1 452');
is($t->app->fw_delete(452), 0, 'fw_delete1 452 non existent');
is($t->app->fw_delete(450), 1, 'fw_delete1 450');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

note "with newlines";
$test_f = path($testdir, 'firewall.clients2');
$t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(450), 1, 'fw_delete2 450');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

note "without rules";
$test_f = path($testdir, 'firewall.clients3');
$t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(450), 1, 'fw_delete3 450');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

note "without commit";
$test_f = path($testdir, 'firewall.clients4');
$t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(450), 1, 'fw_delete4 450');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
undef $t;

note "intersecting ids: 45 and 450";
$test_f = path($testdir, 'firewall.clients5');
$t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(45), 0, 'fw_delete5 45 non existent');
is($t->app->fw_delete(450), 1, 'fw_delete5 450');
compare_ok($test_f, path($testdir, 'result5'), 'compare results 5');
undef $t;

note "duplicate ids, issue warnings";
$test_f = path($testdir, 'firewall.clients6');
$t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, rlog_local=>1, rlog_remote=>0});
is($t->app->fw_delete(450), 1, 'fw_delete6 450 duplicate ids, issue warnings');
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
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451
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

COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
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
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451

# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result2
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:ICMP_ONLY - [0:0]
-A ICMP_ONLY -p icmp -j ACCEPT
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451 -j ACCEPT

COMMIT

*mangle
# 451
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451

# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
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
COMMIT
*mangle
# 451
# 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
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
*mangle
@@ firewall.clients5
# WARNING: this is autogenerated file, don't run or change it!
*filter
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
COMMIT
*mangle
# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
COMMIT
@@ result5
# WARNING: this is autogenerated file, don't run or change it!
*filter
COMMIT
*mangle
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
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450
# 450
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 451
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 451
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result6
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
__END__
