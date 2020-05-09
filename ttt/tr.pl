#!/usr/bin/perl

use NetAddr::IP;
use warnings;

my $client_in_chain = 'pipe_in_inet_clients';
my $client_out_chain = 'pipe_out_inet_clients';
my $iptables_path = '/usr/sbin/iptables';

###
# debug (iptables [-t mangle] -N testchain_in/testchain_out)
#$client_in_chain = 'testchain_in';
#$client_out_chain = 'testchain_out';

# create rule dumps
my @dump_m_in = `$iptables_path -t mangle -nvx --line-numbers -L $client_in_chain`;
if ($?) {
  die "Error dumping rules $client_in_chain in mangle table!";
}


###
my $ri = 1; # actual rule index
for (my $i = 2; $i < @dump_m_in; $i++) { # skip first 2 lines
  $_ = $dump_m_in[$i];
  print;
  # n pkt bytes MARK all -- * * 0.0.0.0/0 10.15.0.2 MARK set 0x4
  # n pkt bytes      all -- * * 0.0.0.0/0 10.15.0.2
  if (/^\s*\d+\s+ \S+\s+ \S+\s+ (\S*)\s+ \S+\s+ \-\-\s+ \S+\s+ \S+\s+ \S+\s+ (\S+)\s+ (.*)/x) {
    print "mangle-in: jump=$1 ip=$2 ext=$3";
    #my $jm_in = $1; $jm_in = '' unless defined $jm_in;
    #my $jm_in_ext = $3;
    $3 =~ /mark set ((?:0x)?\w+)/i;
    my $jm_in_mark = ($1) ? $1 : -1;
    $jm_in_mark = oct($jm_in_mark) if $jm_in_mark =~ /^0/;
    print " qsmark=$jm_in_mark\n";


  }
}

exit;

