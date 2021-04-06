use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Data::Dumper;
use lib '../ljq/lib';

diag "prepare data...";
my %td;
my $lref;
while (<DATA>) {
  last if /^__END__$/;
  if (/^@@ *(\S+)$/) {
    diag "prepare $1";
    $lref = $td{$1} = [];
    next;
  }
  push @$lref, $_ if $lref;
}

my $t = Test::Mojo->new('Gwsyn', { client_in_chain=>'in_test', client_out_chain=>'out_test',
  my_profiles=>['gwtest1'],
  worker_db_file=>'/tmp/test$$.dat',
});
#say Dumper \%td;

my ($ri, $ip);

my $m = $t->app->fw_matang;
for my $n (qw/f_in f_out m_in m_out/) {
  my $c = 0;
  $ri = 0;
  $ip = undef;
  for (@{$td{ $n }}) {
    next if ++$c < 3;
    if ($_ =~ $m->{ $n }{re1}(12)) { $ri = $1; $ip = $2; }
  }
  ok($ri == 3 && $ip eq '1.2.3.5', "$n grepping for id 12");
}

for my $n (qw/f_in f_out m_in m_out/) {
  my $c = 0;
  $ri = 0;
  $ip = undef;
  for (@{$td{ $n }}) {
    next if ++$c < 3;
    if ($_ =~ $m->{ $n }{re1}(1)) { $ri = $1; $ip = $2; }
  }
  ok($ri == 1 && $ip eq '1.2.3.1', "$n grepping for id 1");
}

done_testing();

__DATA__
@@ f_in
Chain in_test (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       0.0.0.0/0            1.2.3.1              /* 1 */
2           0        0 ICMP_ONLY  all  --  *      *       0.0.0.0/0            1.2.3.2              /* 2 */
3           0        0 DROP       all  --  *      *       0.0.0.0/0            1.2.3.5              /* 12 */
4           0        0 HTTP_IM_ICMP  all  --  *      *       0.0.0.0/0            1.2.3.6              /* 13 */
@@ f_out
Chain out_test (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0 ACCEPT     all  --  *      *       1.2.3.1              0.0.0.0/0            /* 1 */
2           0        0 ICMP_ONLY  all  --  *      *       1.2.3.2              0.0.0.0/0            /* 2 */ MAC 11:22:33:44:55:66
3           0        0 DROP       all  --  *      *       1.2.3.5              0.0.0.0/0            /* 12 */ MAC 11:22:33:44:55:77
4           0        0 HTTP_IM_ICMP  all  --  *      *       1.2.3.6              0.0.0.0/0            /* 13 */ MAC 11:22:33:44:55:88
@@ m_in
Chain in_test (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0            all  --  *      *       0.0.0.0/0            1.2.3.1              /* 1 */
2           0        0            all  --  *      *       0.0.0.0/0            1.2.3.2              /* 2 */
3           0        0            all  --  *      *       0.0.0.0/0            1.2.3.5              /* 12 */
4           0        0            all  --  *      *       0.0.0.0/0            1.2.3.6              /* 13 */
@@ m_out
Chain out_test (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0            all  --  *      *       1.2.3.1              0.0.0.0/0            /* 1 */
2           0        0            all  --  *      *       1.2.3.2              0.0.0.0/0            /* 2 */
3           0        0            all  --  *      *       1.2.3.5              0.0.0.0/0            /* 12 */
4           0        0            all  --  *      *       1.2.3.6              0.0.0.0/0            /* 13 */
__END__
