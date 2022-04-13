use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';
use Data::Dumper;

plan skip_all => 'Set TEST_REAL_IPTABLES_AND_ROOT=1 variable to enable this test.' unless $ENV{TEST_REAL_IPTABLES_AND_ROOT};
plan skip_all => "This test must be run under root. Current uid: $>." if $>;

my $ipt = '/usr/sbin/iptables';
my $test_out_chain = 'test_out_chain';

# create or flush test chains
for (qw/mangle/) {
  system "$ipt -t $_ -N $test_out_chain";
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

my $t = Test::Mojo->new('Rtsyn', {
  iptables_path => $ipt,
  client_out_chain => $test_out_chain,
  rlog_local => 1, rlog_remote => 0,
  my_profiles => ['plk'],
  worker_db_file => '/tmp/test$$.dat',
});

my $tm = $t->app->rt_matang;

# adding rules
is($t->app->rt_add_replace_rules({id=>11, ip=>'192.168.1.1', rt=>0}), 1, 'rt_add_replace_rules, add id=11, rt=0');
is($t->app->rt_add_replace_rules({id=>12, ip=>'192.168.1.2', rt=>1}), 1, 'rt_add_replace_rules, add id=12, rt=1');
is($t->app->rt_add_replace_rules({id=>13, ip=>'192.168.1.3', rt=>0}), 1, 'rt_add_replace_rules, add id=13, rt=0');
is($t->app->rt_add_replace_rules({id=>14, ip=>'192.168.1.4', rt=>1}), 1, 'rt_add_replace_rules, add id=14, rt=1');
compare_rules($tm, 1);

# replace rules
is($t->app->rt_add_replace_rules({id=>11, ip=>'192.168.1.11', rt=>1}), 1, 'rt_add_replace_rules, replace id=11, rt=1');
is($t->app->rt_add_replace_rules({id=>14, ip=>'192.168.1.14', rt=>0}), 1, 'rt_add_replace_rules, replace id=14, rt=0');
is($t->app->rt_add_replace_rules({id=>15, ip=>'192.168.1.15', rt=>0}), 1, 'rt_add_replace_rules, add id=15, rt=0');
is($t->app->rt_add_replace_rules({id=>16, ip=>'192.168.1.16', rt=>1}), 1, 'rt_add_replace_rules, add id=16, rt=1');
compare_rules($tm, 2);

# delete rules
is($t->app->rt_delete_rules(11), 1, 'rt_delete_rules, id=11');
is($t->app->rt_delete_rules(13), 1, 'rt_delete_rules, id=13');
is($t->app->rt_delete_rules(16), 1, 'rt_delete_rules, id=16');
is($t->app->rt_delete_rules(11), 0, 'rt_delete_rules, id=11, not existed, return 0');
compare_rules($tm, 3);


done_testing();

# compare_rules($tm, $index);
sub compare_rules {
  my ($tm, $index) = @_;
  for my $n (qw/m_out/) {
    my $m = $tm->{$n};
    die "Matang $n matanga!" unless $m;
    
    my $dump = $m->{dump_sub}();
    die "Error dumping rules $m->{chain} in $m->{table}!" unless $dump;
    my $r1 = join('', @$dump);
    is($r1, $results{$n.$index}, "Compare rules $n$index");
  }
}

__DATA__
@@ m_out1
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0            all  --  *      *       192.168.1.1          0.0.0.0/0            /* 11 */
2           0        0 MARK       all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */ MARK set 0x2
3           0        0            all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */
4           0        0 MARK       all  --  *      *       192.168.1.4          0.0.0.0/0            /* 14 */ MARK set 0x2
@@ m_out2
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.11         0.0.0.0/0            /* 11 */ MARK set 0x2
2           0        0 MARK       all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */ MARK set 0x2
3           0        0            all  --  *      *       192.168.1.3          0.0.0.0/0            /* 13 */
4           0        0            all  --  *      *       192.168.1.14         0.0.0.0/0            /* 14 */
5           0        0            all  --  *      *       192.168.1.15         0.0.0.0/0            /* 15 */
6           0        0 MARK       all  --  *      *       192.168.1.16         0.0.0.0/0            /* 16 */ MARK set 0x2
@@ m_out3
Chain test_out_chain (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 MARK       all  --  *      *       192.168.1.2          0.0.0.0/0            /* 12 */ MARK set 0x2
2           0        0            all  --  *      *       192.168.1.14         0.0.0.0/0            /* 14 */
3           0        0            all  --  *      *       192.168.1.15         0.0.0.0/0            /* 15 */
__END__
