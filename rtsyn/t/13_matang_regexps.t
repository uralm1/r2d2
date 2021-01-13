use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Data::Dumper;

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

my $t = Test::Mojo->new('Rtsyn', {client_out_chain=>'out_test'});
#say Dumper \%td;

my ($ri, $ip);

my $m = $t->app->rt_matang;
for my $n (qw/m_out/) {
  my $c = 0;
  $ri = 0;
  $ip = undef;
  for (@{$td{ $n }}) {
    next if ++$c < 3;

    if ($_ =~ $m->{ $n }{re1}(12)) { $ri = $1; $ip = $2; }
  }
  ok($ri == 3 && $ip eq '1.2.3.5', "$n grepping for id 12");
}

for my $n (qw/m_out/) {
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
@@ m_out
Chain out_test (0 references)
num      pkts      bytes target     prot opt in     out     source               destination         
1           0        0   MARK     all  --  *      *       1.2.3.1              0.0.0.0/0            /* 1 */ MARK set 0x2
2           0        0            all  --  *      *       1.2.3.2              0.0.0.0/0            /* 2 */
3           0        0   MARK     all  --  *      *       1.2.3.5              0.0.0.0/0            /* 12 */ MARK set 0x2
4           0        0            all  --  *      *       1.2.3.6              0.0.0.0/0            /* 13 */
__END__
