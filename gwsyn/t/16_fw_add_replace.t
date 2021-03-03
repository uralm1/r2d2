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


# my $t = $make_test->($test_mojo_file);
my $make_test = sub {
  my $tf = shift;
  return Test::Mojo->new('Gwsyn', { firewall_file => $tf->to_string,
    client_in_chain=>'pipe_in_inet_clients', client_out_chain=>'pipe_out_inet_clients',
    rlog_local=>1, rlog_remote=>0,
    my_profiles=>['gwtest1'],
  });
};

note "common usage";
my $test_f = path($testdir, 'firewall.clients1');
my $t = $make_test->($test_f);
is($t->app->fw_add_replace({id=>451,ip=>'1.2.4.51',mac=>'44:44:44:44:44:44',defjump=>'DROP'}), 1, 'fw_add_replace1 451 replaced');
is($t->app->fw_add_replace({id=>450,ip=>'1.2.4.50',mac=>'',defjump=>'ACCEPT'}), 1, 'fw_add_replace1 450 replaced');
is($t->app->fw_add_replace({id=>452,ip=>'1.2.4.52',defjump=>'ACCEPT'}), 1, 'fw_add_replace1 452 replaced');
is($t->app->fw_add_replace({id=>10,ip=>'1.2.3.10',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace1 10 added');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

note "bad format";
$test_f = path($testdir, 'firewall.clients2');
$t = $make_test->($test_f);
is($t->app->fw_add_replace({id=>1,ip=>'1.2.3.1',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace2 1 added');
is($t->app->fw_add_replace({id=>2,ip=>'1.2.3.2',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace2 2 added');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

note "regex intersections and formats";
$test_f = path($testdir, 'firewall.clients3');
$t = $make_test->($test_f);
is($t->app->fw_add_replace({id=>10,ip=>'1.2.3.10',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace3 10 added');
is($t->app->fw_add_replace({id=>2,ip=>'1.2.3.2',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace3 2 added');
is($t->app->fw_add_replace({id=>1,ip=>'1.2.3.1',mac=>'44:44:44:44:44:44',defjump=>'ACCEPT'}), 1, 'fw_add_replace3 1 added');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

note "duplicate ids, issue warnings";
$test_f = path($testdir, 'firewall.clients4');
$t = $make_test->($test_f);
is($t->app->fw_add_replace({id=>450,ip=>'192.168.34.45',mac=>'11:11:11:11:11:11',defjump=>'ACCEPT'}), 1, 'fw_add_replace4 450 replaced, duplicate ids removed, warnings issued');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
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

# 450
-A pipe_in_inet_clients -d 1.2.4.50 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.4.50 -m comment --comment 450 -j ACCEPT
# 451
-A pipe_in_inet_clients -d 1.2.4.51 -m comment --comment 451 -j DROP
-A pipe_out_inet_clients -s 1.2.4.51 -m comment --comment 451 -m mac --mac-source 44:44:44:44:44:44 -j DROP
# 452
-A pipe_in_inet_clients -d 1.2.4.52 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.4.52 -m comment --comment 452 -j ACCEPT
# 10
-A pipe_in_inet_clients -d 1.2.3.10 -m comment --comment 10 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.3.10 -m comment --comment 10 -m mac --mac-source 44:44:44:44:44:44 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
# 450
-A pipe_in_inet_clients -d 1.2.4.50 -m comment --comment 450
-A pipe_out_inet_clients -s 1.2.4.50 -m comment --comment 450
# 451
-A pipe_in_inet_clients -d 1.2.4.51 -m comment --comment 451
-A pipe_out_inet_clients -s 1.2.4.51 -m comment --comment 451
# 452
-A pipe_in_inet_clients -d 1.2.4.52 -m comment --comment 452
-A pipe_out_inet_clients -s 1.2.4.52 -m comment --comment 452
# 10
-A pipe_in_inet_clients -d 1.2.3.10 -m comment --comment 10
-A pipe_out_inet_clients -s 1.2.3.10 -m comment --comment 10
COMMIT
@@ firewall.clients2
@@ result2
# WARNING: this is autogenerated file, don't run or change it!

# 2
-A pipe_in_inet_clients -d 1.2.3.2 -m comment --comment 2 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.3.2 -m comment --comment 2 -m mac --mac-source 44:44:44:44:44:44 -j ACCEPT
COMMIT

# 2
-A pipe_in_inet_clients -d 1.2.3.2 -m comment --comment 2
-A pipe_out_inet_clients -s 1.2.3.2 -m comment --comment 2
COMMIT
@@ firewall.clients3
# WARNING: this is autogenerated file, don't run or change it!
*filter

COMMIT

*mangle
@@ result3
# WARNING: this is autogenerated file, don't run or change it!

*filter

# 10
-A pipe_in_inet_clients -d 1.2.3.10 -m comment --comment 10 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.3.10 -m comment --comment 10 -m mac --mac-source 44:44:44:44:44:44 -j ACCEPT
# 2
-A pipe_in_inet_clients -d 1.2.3.2 -m comment --comment 2 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.3.2 -m comment --comment 2 -m mac --mac-source 44:44:44:44:44:44 -j ACCEPT
# 1
-A pipe_in_inet_clients -d 1.2.3.1 -m comment --comment 1 -j ACCEPT
-A pipe_out_inet_clients -s 1.2.3.1 -m comment --comment 1 -m mac --mac-source 44:44:44:44:44:44 -j ACCEPT
COMMIT

*mangle
# 10
-A pipe_in_inet_clients -d 1.2.3.10 -m comment --comment 10
-A pipe_out_inet_clients -s 1.2.3.10 -m comment --comment 10
# 2
-A pipe_in_inet_clients -d 1.2.3.2 -m comment --comment 2
-A pipe_out_inet_clients -s 1.2.3.2 -m comment --comment 2
# 1
-A pipe_in_inet_clients -d 1.2.3.1 -m comment --comment 1
-A pipe_out_inet_clients -s 1.2.3.1 -m comment --comment 1
COMMIT
@@ firewall.clients4
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
-A pipe_in_inet_clients -d 192.168.34.23 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.23 -m comment --comment 450 -m mac --mac-source 11:22:33:44:55:66 -j ACCEPT
# 450
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 450 -j ACCEPT
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
-A pipe_in_inet_clients -d 192.168.34.24 -m comment --comment 450
-A pipe_out_inet_clients -s 192.168.34.24 -m comment --comment 450
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
@@ result4
# WARNING: this is autogenerated file, don't run or change it!

*filter
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]

# 450
-A pipe_in_inet_clients -d 192.168.34.45 -m comment --comment 450 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.45 -m comment --comment 450 -m mac --mac-source 11:11:11:11:11:11 -j ACCEPT
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452 -j ACCEPT
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452 -m mac --mac-source 11:22:33:44:55:88 -j ACCEPT
COMMIT

*mangle
:pipe_in_inet_clients - [0:0]
:pipe_out_inet_clients - [0:0]
# 450
-A pipe_in_inet_clients -d 192.168.34.45 -m comment --comment 450
-A pipe_out_inet_clients -s 192.168.34.45 -m comment --comment 450
# 452
-A pipe_in_inet_clients -d 192.168.34.25 -m comment --comment 452
-A pipe_out_inet_clients -s 192.168.34.25 -m comment --comment 452
COMMIT
__END__
