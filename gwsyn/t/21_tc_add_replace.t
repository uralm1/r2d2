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
  return Test::Mojo->new('Gwsyn', { tc_file => $tf->to_string, tc_path=>'/usr/sbin/tc',
    rlog_local=>1, rlog_remote=>0,
    my_profiles=>['gwtest1'],
  });
};

note "common usage";
my $test_f = path($testdir, 'traf.clients1');
my $t = $make_test->($test_f);
is($t->app->tc_add_replace({id=>451,ip=>'1.2.4.51'}), 1, 'tc_add_replace1 451 replaced');
is($t->app->tc_add_replace({id=>450,ip=>'1.2.4.50',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace1 450 replaced');
is($t->app->tc_add_replace({id=>452,ip=>'1.2.4.52'}), 1, 'tc_add_replace1 452 replaced');
is($t->app->tc_add_replace({id=>14,ip=>'1.2.3.14',speed_in=>'rate 64kbit prio 5'}), 1, 'tc_add_replace1 14 added');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');
undef $t;

note "removed last, added one and intersecting ids: 45 and 450";
$test_f = path($testdir, 'traf.clients2');
$t = $make_test->($test_f);
is($t->app->tc_add_replace({id=>450,ip=>'1.2.4.50',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace2 450 replaced');
is($t->app->tc_add_replace({id=>45,ip=>'1.2.4.50',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace2 45 added');
compare_ok($test_f, path($testdir, 'result2'), 'compare results 2');
undef $t;

note "add to empty file";
$test_f = path($testdir, 'traf.clients3');
$t = $make_test->($test_f);
is($t->app->tc_add_replace({id=>1,ip=>'1.2.1.1',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace3 1 added');
is($t->app->tc_add_replace({id=>2,ip=>'1.2.1.2',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace3 2 added');
is($t->app->tc_add_replace({id=>1,ip=>'1.2.1.1'}), 1, 'tc_add_replace3 1 replaced');
compare_ok($test_f, path($testdir, 'result3'), 'compare results 3');
undef $t;

note "replace with duplicate ids, issue warnings";
$test_f = path($testdir, 'traf.clients4');
$t = $make_test->($test_f);
is($t->app->tc_add_replace({id=>450,ip=>'192.168.34.45',speed_in=>'rate 64kbit prio 5',speed_out=>'rate 64kbit prio 5'}), 1, 'tc_add_replace4 450 replaced, duplicate ids removed, warnings issued');
compare_ok($test_f, path($testdir, 'result4'), 'compare results 4');
undef $t;

done_testing();

__DATA__
@@ traf.clients1
# WARNING: this is autogenerated file, don't run or change it!

# 300 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 1mbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.23 flowid 1:300
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 2mbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.23 flowid 1:300

# 301 451
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.24 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.24 flowid 1:301

# 302 452
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.25 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.25 flowid 1:302

@@ result1
# WARNING: this is autogenerated file, don't run or change it!

# 300 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.4.50 flowid 1:300
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:300 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.4.50 flowid 1:300

# 301 451
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.4.51 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.4.51 flowid 1:301

# 302 452
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.4.52 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.4.52 flowid 1:302

# 303 14
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:303 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:303 handle 303: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.3.14 flowid 1:303
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:303 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:303 handle 303: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.3.14 flowid 1:303

@@ traf.clients2
# WARNING: this is autogenerated file, don't run or change it!
# 300 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 1mbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.23 flowid 1:300
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 2mbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.23 flowid 1:300
# 301 451
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.24 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.24 flowid 1:301
@@ result2
# WARNING: this is autogenerated file, don't run or change it!
# 301 451
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.24 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.24 flowid 1:301
# 302 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.4.50 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.4.50 flowid 1:302

# 303 45
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:303 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:303 handle 303: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.4.50 flowid 1:303
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:303 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:303 handle 303: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.4.50 flowid 1:303

@@ traf.clients3
@@ result3
# 301 1
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.1.1 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.1.1 flowid 1:301

# 302 2
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 1.2.1.2 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 1.2.1.2 flowid 1:302

@@ traf.clients4
# WARNING: this is autogenerated file, don't run or change it!

# 300 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 1mbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.23 flowid 1:300
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:300 htb quantum 6400 rate 2mbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.23 flowid 1:300

# 301 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.24 flowid 1:301
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:301 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:301 handle 301: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.24 flowid 1:301

# 302 452
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.25 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.25 flowid 1:302

@@ result4
# WARNING: this is autogenerated file, don't run or change it!

# 300 450
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:300 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.45 flowid 1:300
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:300 htb rate 64kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:300 handle 300: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.45 flowid 1:300

# 302 452
/usr/sbin/tc class add dev $INTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $INTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst 192.168.34.25 flowid 1:302
/usr/sbin/tc class add dev $EXTR_IF parent 1:10 classid 1:302 htb quantum 6400 rate 256kbit prio 5
/usr/sbin/tc qdisc add dev $EXTR_IF parent 1:302 handle 302: pfifo limit 100
/usr/sbin/tc filter add dev $EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src 192.168.34.25 flowid 1:302

__END__
