use Mojo::Base -strict;

use Test::Mojo;
use Test::More;

my $c = {
  disable_autoload => 1,

  my_profile => 'plk',

  local_cert => '../cert/localhost-cert.pem',
  local_key => '../cert/localhost-key.pem',
  ca => '../cert/ca.pem',

  head_url => 'https://localhost:2271',

  iptables_path => '/usr/sbin/iptables',
  iptables_restore_path => '/usr/sbin/iptables-restore',

  client_out_chain => 'pipe_out_inet_clients', # mangle chain name

  iptables_wait => 3,
  iptables_simulation => 1,
};

my $t = Test::Mojo->new('Rtsyn' => $c);

$t->get_ok('/subsys')->status_is(200)->content_like(qr/^rtsyn/);
$t->get_ok('/subsys?format=json')->status_is(200)
  ->json_like('/subsys'=>qr/^rtsyn/)
  ->json_has('/version')
  ->json_has('/profile');

done_testing();
