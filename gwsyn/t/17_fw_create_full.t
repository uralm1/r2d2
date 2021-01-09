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

my $test_f = path($testdir, 'firewall.clients1');
my $t = Test::Mojo->new('Gwsyn', {firewall_file => $test_f->to_string, my_profile => 'gwtest1',
  client_in_chain=>'in_test', client_out_chain=>'out_test'});
my $j = [
  {id=>11, ip=> '1.2.3.4', mac=>'11:22:33:44:55:66', defjump=>'ACCEPT', profile=>'zzz'},
  {id=>1, ip=> '1.2.3.1', defjump=>'ACCEPT', profile=>'gwtest1'},
  {id=>2, ip=> '1.2.3.2', mac=>'11:22:33:44:55:66', defjump=>'ICMP_ONLY', profile=>'gwtest1', no_dhcp=>1},
  {id=>12, ip=> '1.2.3.5', mac=>'11:22:33:44:55:77', defjump=>'DROP', profile=>'gwtest1'},
  {id=>13, ip=> '1.2.3.6', mac=>'11:22:33:44:55:88', defjump=>'HTTP_IM_ICMP', profile=>'gwtest1'},
  {id=>14, ip=> '1.2.3.7', mac=>'11:22:33:44:55:99', defjump=>'ACCEPT'},
];
is($t->app->fw_create_full($j), 1, 'fw_create_full1');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');

done_testing();

__DATA__
@@ result1
# WARNING: this is autogenerated file, don't run or change it!

*filter
:in_test - [0:0]
:out_test - [0:0]
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

# 1
-A in_test -d 1.2.3.1 -m comment --comment 1 -j ACCEPT
-A out_test -s 1.2.3.1 -m comment --comment 1 -j ACCEPT
# 2
-A in_test -d 1.2.3.2 -m comment --comment 2 -j ICMP_ONLY
-A out_test -s 1.2.3.2 -m comment --comment 2 -m mac --mac-source 11:22:33:44:55:66 -j ICMP_ONLY
# 12
-A in_test -d 1.2.3.5 -m comment --comment 12 -j DROP
-A out_test -s 1.2.3.5 -m comment --comment 12 -m mac --mac-source 11:22:33:44:55:77 -j DROP
# 13
-A in_test -d 1.2.3.6 -m comment --comment 13 -j HTTP_IM_ICMP
-A out_test -s 1.2.3.6 -m comment --comment 13 -m mac --mac-source 11:22:33:44:55:88 -j HTTP_IM_ICMP
COMMIT

*mangle
:in_test - [0:0]
:out_test - [0:0]
# 1
-A in_test -d 1.2.3.1 -m comment --comment 1
-A out_test -s 1.2.3.1 -m comment --comment 1
# 2
-A in_test -d 1.2.3.2 -m comment --comment 2
-A out_test -s 1.2.3.2 -m comment --comment 2
# 12
-A in_test -d 1.2.3.5 -m comment --comment 12
-A out_test -s 1.2.3.5 -m comment --comment 12
# 13
-A in_test -d 1.2.3.6 -m comment --comment 13
-A out_test -s 1.2.3.6 -m comment --comment 13
COMMIT
__END__
