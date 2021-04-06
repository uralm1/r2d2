use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use lib '../ljq/lib';
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

my $t = Test::Mojo->new('Dhcpsyn', { dhcpscope=>'10.0.0.0',
  my_profiles=>['plk'],
  worker_db_file=>'/tmp/test$$.dat',
});
#say Dumper \%td;

my @got;

my $m = $t->app->dhcp_matang;
for my $n (qw/win_dhcp/) {
  for (@{$td{ $n }}) {
    if ($_ =~ $m->{ $n }{re2}('10.1.0.1')) { push @got, { ip=>$1, mac=>$2, c=>$3 } }
  }
  is_deeply(\@got,
    [
      {ip=>'10.11.0.1', mac=>'001122334455', c=>'client1'},
      {ip=>'10.11.0.2', mac=>'aabbccddeeff', c=>''},
      {ip=>'10.11.0.3', mac=>'010203040506', c=>'client3'},
    ],
    "$n dhcpserver 10.1.0.1 dump regexp"
  );
}

@got = ();
for my $n (qw/win_dhcp/) {
  for (@{$td{ $n }}) {
    if ($_ =~ $m->{ $n }{re2}('10.1.0.2')) { push @got, { ip=>$1, mac=>$2, c=>$3 } }
  }
  is_deeply(\@got,
    [
      {ip=>'10.11.0.4', mac=>'010203040506', c=>'client4'},
    ],
    "$n dhcpserver 10.1.0.2 dump regexp"
  );
}

@got = ();
for my $n (qw/win_dhcp/) {
  for (@{$td{ $n }}) {
    if ($_ =~ $m->{ $n }{re1}('10.1.0.1', 1)) { push @got, { ip=>$1, mac=>$2 } }
  }
  is_deeply(\@got,
    [ {ip=>'10.11.0.1', mac=>'001122334455'} ],
    "$n dhcpserver 10.1.0.1 search for clientid 1 regexp"
  );
}

@got = ();
for my $n (qw/win_dhcp/) {
  for (@{$td{ $n }}) {
    if ($_ =~ $m->{ $n }{re1}('10.1.0.2', 4)) { push @got, { ip=>$1, mac=>$2 } }
  }
  is_deeply(\@got,
    [ {ip=>'10.11.0.4', mac=>'010203040506'} ],
    "$n dhcpserver 10.1.0.2 search for clientid 4 regexp"
  );
}

@got = ();
for my $n (qw/win_dhcp/) {
  for (@{$td{ $n }}) {
    if ($_ =~ $m->{ $n }{re1}('10.1.0.2', 1)) { push @got, { ip=>$1, mac=>$2 } }
  }
  is_deeply(\@got,
    [],
    "$n dhcpserver 10.1.0.2 search for clientid 1 regexp - not found"
  );
}

done_testing();

__DATA__
@@ win_dhcp
# ============================================================================
Dhcp Server 10.1.0.1 Scope 10.0.0.0 Add iprange 10.10.1.1 10.10.1.255 

Dhcp Server 10.1.0.1 Scope 10.0.0.0 set optionvalue 66 STRING "10.5.1.2" 
Dhcp Server 10.1.0.1 Scope 10.0.0.0 Add reservedip 10.11.0.1 001122334455 "test1.dom" "client1" "DHCP"
Dhcp Server \\10.1.0.1 Scope 10.0.0.0 Add reservedip 10.11.0.2 aabbccddeeff "test2.dom" "" "BOTH"
Dhcp Server 10.1.0.1 Scope 10.0.0.0 Add reservedip 10.11.0.3 010203040506 "BAD_ADDRESS" "client3" "DHCP"
Dhcp Server 10.1.0.2 Scope 10.0.0.0 Add reservedip 10.11.0.4 010203040506 "test3.dom" "client4" "DHCP"
Dhcp Server 10.1.0.1 Scope 102.168.1.0 Add reservedip 10.11.0.5 010203040506 "test4.dom" "client5" "DHCP"
# ============================================================================
__END__
