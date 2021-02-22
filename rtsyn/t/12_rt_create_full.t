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

my $test_f = path($testdir, 'firewall-rtsyn.clients1');
my $t = Test::Mojo->new('Rtsyn', {firewall_file => $test_f->to_string, my_profiles => ['gwtest1'],
  client_out_chain=>'out_test'});
my $j = [
  {id=>11, ip=> '1.2.3.4', rt=>0, profile=>'zzz'},
  {id=>1, ip=> '1.2.3.1', rt=>0, profile=>'gwtest1'},
  {id=>2, ip=> '1.2.3.2', rt=>1, profile=>'gwtest1'},
  {id=>12, ip=> '1.2.3.5', rt=>1, profile=>'gwtest1'},
  {id=>13, ip=> '1.2.3.6', rt=>0, profile=>'gwtest1'},
  {id=>14, ip=> '1.2.3.7', rt=>0},
];
is($t->app->rt_create_full($j), 1, 'rt_create_full1');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');

done_testing();

__DATA__
@@ result1
# WARNING: this is autogenerated file, don't run or change it!

*mangle
:out_test - [0:0]

-A out_test -s 1.2.3.1 -m comment --comment 1 
-A out_test -s 1.2.3.2 -m comment --comment 2 -j MARK --set-mark 2
-A out_test -s 1.2.3.5 -m comment --comment 12 -j MARK --set-mark 2
-A out_test -s 1.2.3.6 -m comment --comment 13 
COMMIT
__END__
