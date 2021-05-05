use Mojo::Base -strict;

use Test::More;

use Ui::Ural::LogColorer;

my $t = Ui::Ural::LogColorer->new;
isa_ok($t, 'Ui::Ural::LogColorer');


for (1, 2) {
  my $c = 1;
  for my $col (@{$t->{colors}}) {
    is $t->color("$c"), $col, "str '$c', color $col";
    $c++;
  }
}
is $t->color("aaa"), $t->{colors}[0], "str 'aaa', color $t->{colors}[0]";
is $t->color("bbb"), $t->{colors}[1], "str 'bbb', color $t->{colors}[1]";

$t->{colors} = [];
$t->{d} = {};
$t->{next_color} = 0;

is $t->color("1"), $t->{default_color}, "no colors - default 1";
is $t->color("2"), $t->{default_color}, "no colors - default 2";

done_testing;
