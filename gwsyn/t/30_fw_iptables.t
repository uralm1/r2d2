use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';
use Data::Dumper;

plan skip_all => 'Set TEST_REAL_IPTABLES_AND_ROOT=1 variable to enable this test.' unless $ENV{TEST_REAL_IPTABLES_AND_ROOT};
plan skip_all => "This test must be run under root. Current uid: $>." if $>;

my $ipt = '/usr/sbin/iptables';
my $test_in_chain = 'test_in_chain';
my $test_out_chain = 'test_out_chain';

# create or flush test chains
for (qw/filter mangle/) {
  system "$ipt -t $_ -N $test_in_chain";
  system "$ipt -t $_ -N $test_out_chain";
  system "$ipt -t $_ -F $test_in_chain";
  system "$ipt -t $_ -F $test_out_chain";
}

# read results into hash
my %results;
my $key;
while (<DATA>) {
  last if /^__END__$/;
  if (/^@@ *(\S+)$/) {
    $key = $1;
    next;
  }
  $results{$key} .= $_ if $key;
}

my $t = Test::Mojo->new('Gwsyn', {
  iptables_path => $ipt,
  client_in_chain => $test_in_chain,
  client_out_chain => $test_out_chain,
  rlog_local => 1, rlog_remote => 0,
  my_profiles => ['plk'],
  worker_db_file => '/tmp/test$$.dat',
});

my $tm = $t->app->fw_matang;

# adding rules
is($t->app->fw_add_replace_rules({id=>11, ip=>'192.168.1.1', mac=>'11:22:33:44:55:66', defjump=>'ACCEPT'}), 1, 'fw_add_replace_rules, add id=11');
is($t->app->fw_add_replace_rules({id=>12, ip=>'192.168.1.2', defjump=>'ACCEPT'}), 1, 'fw_add_replace_rules, add id=12');
is($t->app->fw_add_replace_rules({id=>13, ip=>'192.168.1.3', defjump=>'DROP', blocked=>1, qs=>2}), 1, 'fw_add_replace_rules, add id=13, blocked');
is($t->app->fw_add_replace_rules({id=>14, ip=>'192.168.1.4', defjump=>'ACCEPT', blocked=>1, qs=>3}), 1, 'fw_add_replace_rules, add id=14, blocked');
compare_rules($tm, 1);

# replace rules
is($t->app->fw_add_replace_rules({id=>11, ip=>'192.168.1.11', defjump=>'DROP', blocked=>1, qs=>3}), 1, 'fw_add_replace_rules, replace id=11, to be added to mangle');
is($t->app->fw_add_replace_rules({id=>14, ip=>'192.168.1.14', mac=>'11:22:33:44:55:66', defjump=>'ACCEPT'}), 1, 'fw_add_replace_rules, replace id=14, to be deleted from mangle');
is($t->app->fw_add_replace_rules({id=>15, ip=>'192.168.1.15', defjump=>'ACCEPT', blocked=>1, qs=>0}), 1, 'fw_add_replace_rules, add id=15');
is($t->app->fw_add_replace_rules({id=>16, ip=>'192.168.1.16', defjump=>'ACCEPT', blocked=>1, qs=>2}), 1, 'fw_add_replace_rules, add id=16, blocked');
compare_rules($tm, 2);

# block rules
is($t->app->fw_block_rules(11, 0), 1, 'fw_block_rules, unblock id=11, to be deleted from mangle');
is($t->app->fw_block_rules(16, 3), 1, 'fw_block_rules, reblock id=16, to be replaced in mangle');
is($t->app->fw_block_rules(99, 3), 0, 'fw_block_rules, block id=99, not found, no change, return 0');
is($t->app->fw_block_rules(12, 2), 1, 'fw_block_rules, block id=12, to be added to mangle');
is($t->app->fw_block_rules(14, 0), 1, 'fw_block_rules, unblock id=14, already unblocked, no change in mangle but return 1');
compare_rules($tm, 3);

# delete rules
is($t->app->fw_delete_rules(11), 1, 'fw_delete_rules, id=11, not blocked, from filter');
is($t->app->fw_delete_rules(13), 1, 'fw_delete_rules, id=13, blocked, from all tables');
is($t->app->fw_delete_rules(16), 1, 'fw_delete_rules, id=16, blocked, from all tables');
is($t->app->fw_delete_rules(11), 0, 'fw_delete_rules, id=11, not existed, return 0');
compare_rules($tm, 4);


done_testing();

# compare_rules($tm, $index);
sub compare_rules {
  my ($tm, $index) = @_;
  for my $n (qw/f_in f_out m_in m_out/) {
    my $m = $tm->{$n};
    die "Matang $n matanga!" unless $m;
    
    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table}!" unless $dump;
    my $r1 = join('', @$dump);
    is($r1, $results{$n.$index}, "Compare rules $n$index");
  }
}

__DATA__
@@ f_in1
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.1          /* 11 */
2           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */
3           0        0 DROP       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */
4           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.4          /* 14 */
@@ f_out1
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       192.168.1.1          0.0.0.0/0            /* 11 */ MAC 11:22:33:44:55:66
2           0        0 ACCEPT     all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */
3           0        0 DROP       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */
4           0        0 ACCEPT     all  --  *      *       192.168.1.4          0.0.0.0/0            /* 14 */
@@ m_in1
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.4          /* 14 */ MARK set 0x3
@@ m_out1
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       192.168.1.4          0.0.0.0/0            /* 14 */ MARK set 0x3
@@ f_in2
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 DROP       all  --  *      *       0.0.0.0/0            192.168.1.11         /* 11 */
2           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */
3           0        0 DROP       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */
4           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.14         /* 14 */
5           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.15         /* 15 */
6           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.16         /* 16 */
@@ f_out2
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 DROP       all  --  *      *       192.168.1.11         0.0.0.0/0            /* 11 */
2           0        0 ACCEPT     all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */
3           0        0 DROP       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */
4           0        0 ACCEPT     all  --  *      *       192.168.1.14         0.0.0.0/0            /* 14 */ MAC 11:22:33:44:55:66
5           0        0 ACCEPT     all  --  *      *       192.168.1.15         0.0.0.0/0            /* 15 */
6           0        0 ACCEPT     all  --  *      *       192.168.1.16         0.0.0.0/0            /* 16 */
@@ m_in2
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.11         /* 11 */ MARK set 0x3
3           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.16         /* 16 */ MARK set 0x2
@@ m_out2
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       192.168.1.11         0.0.0.0/0            /* 11 */ MARK set 0x3
3           0        0 MARK       all  --  *      *       192.168.1.16         0.0.0.0/0            /* 16 */ MARK set 0x2
@@ f_in3
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 DROP       all  --  *      *       0.0.0.0/0            192.168.1.11         /* 11 */
2           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */
3           0        0 DROP       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */
4           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.14         /* 14 */
5           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.15         /* 15 */
6           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.16         /* 16 */
@@ f_out3
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 DROP       all  --  *      *       192.168.1.11         0.0.0.0/0            /* 11 */
2           0        0 ACCEPT     all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */
3           0        0 DROP       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */
4           0        0 ACCEPT     all  --  *      *       192.168.1.14         0.0.0.0/0            /* 14 */ MAC 11:22:33:44:55:66
5           0        0 ACCEPT     all  --  *      *       192.168.1.15         0.0.0.0/0            /* 15 */
6           0        0 ACCEPT     all  --  *      *       192.168.1.16         0.0.0.0/0            /* 16 */
@@ m_in3
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.3          /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.16         /* 16 */ MARK set 0x3
3           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */ MARK set 0x2
@@ m_out3
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       192.168.1.16         0.0.0.0/0            /* 16 */ MARK set 0x3
3           0        0 MARK       all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */ MARK set 0x2
@@ f_in4
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */
2           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.14         /* 14 */
3           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            192.168.1.15         /* 15 */
@@ f_out4
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */
2           0        0 ACCEPT     all  --  *      *       192.168.1.14         0.0.0.0/0            /* 14 */ MAC 11:22:33:44:55:66
3           0        0 ACCEPT     all  --  *      *       192.168.1.15         0.0.0.0/0            /* 15 */
@@ m_in4
Chain test_in_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       0.0.0.0/0            192.168.1.2          /* 12 */ MARK set 0x2
@@ m_out4
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */ MARK set 0x2
__END__
