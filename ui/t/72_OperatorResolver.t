use Mojo::Base -strict;

use Test::More;
use Test::Exception;
use Mojo::File 'path';

use Ui::Ural::OperatorResolver;

plan skip_all => 'Set TEST_ONLINE=1 variable to enable test with online LDAP' unless $ENV{TEST_ONLINE};

dies_ok( sub { Ui::Ural::OperatorResolver->new }, 'Empty constuctor');

my $cfg = eval path('ui.conf')->slurp;

my $r = Ui::Ural::OperatorResolver->new($cfg);
isa_ok($r, 'Ui::Ural::OperatorResolver');

diag $r->resolve('av');
diag $r->resolve('av');
diag $r->resolve('ural');
diag $r->resolve('av1');
diag $r->resolve('av1');
diag $r->resolve('ural1');
diag $r->resolve('ural1');
diag $r->resolve('ural1');

done_testing();
