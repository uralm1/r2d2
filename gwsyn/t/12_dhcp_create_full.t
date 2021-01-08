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

my $test_f = path($testdir, 'dhcphosts.clients1');
my $t = Test::Mojo->new('Gwsyn', {dhcphosts_file => $test_f->to_string, my_profile => 'gwtest1'});
my $j = [
  {id=>11, ip=> '1.2.3.4', mac=>'11:22:33:44:55:66', profile=>'gwtest1'},
  {id=>1, ip=> '1.2.3.1', profile=>'gwtest1'},
  {id=>2, ip=> '1.2.3.4', mac=>'11:22:33:44:55:66', profile=>'gwtest1', no_dhcp=>1},
  {id=>12, ip=> '1.2.3.5', mac=>'11:22:33:44:55:77', profile=>'gwtest1'},
  {id=>13, ip=> '1.2.3.6', mac=>'11:22:33:44:55:88', profile=>'gwtest1'},
  {id=>14, ip=> '1.2.3.7', mac=>'11:22:33:44:55:99'},
];
is($t->app->dhcp_create_full($j), 1, 'dhcp_create_full1');
compare_ok($test_f, path($testdir, 'result1'), 'compare results 1');

done_testing();

__DATA__
@@ result1
11:22:33:44:55:66,id:*,set:client11,1.2.3.4
11:22:33:44:55:77,id:*,set:client12,1.2.3.5
11:22:33:44:55:88,id:*,set:client13,1.2.3.6
__END__
