use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $t = Test::Mojo->new('Ui');

my $stash;
$t->app->hook(after_dispatch => sub { $stash = shift->stash });

$t->get_ok('/about');

my $status = $t->tx->res->code;
if ($stash->{remote_user}) {
  # debug authorization is enabled
  is($status, 200, 'Warning: Debug authorization IS ACTIVATED!');
  $t->content_like(qr/О программе/, 'About content is good');

} else {
  is($status, 401, 'Authorization required test');
}

done_testing();
