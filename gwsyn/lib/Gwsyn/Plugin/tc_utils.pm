package Gwsyn::Plugin::tc_utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $resp = tcrules_create_full([{id=>11, ip=>'1.2.3.4', speed_in=>'', spped_out=>''}, ...]);
  # fully updates /var/r2d2/traf.clients,
  # returns 1 on success,
  #   dies with 'error string' on error,
  $app->helper(tcrules_create_full => sub {
    my ($self, $va) = @_;
    croak 'Bad argument' unless $va;

    my $tcfile = path($self->config('tc_file'));
    my $tc_path = $self->config('tc_path');

    my $fh = $tcfile->open('>') or die "Can't create tc file: $!";

    print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
    my $traf_id_counter = 300; # start client classid

    # data
    for (@$va) {
      $_->{speed_in} ||= "quantum 6400 rate 256kbit prio 5";
      $_->{speed_out} ||= "quantum 6400 rate 256kbit prio 5";
      print $fh "# $_->{id}\n";
      #print $fh "$tc_path -batch <<EOF\n";
      print $fh "$tc_path class add dev \$INTR_IF parent 1:10 classid 1:$traf_id_counter htb $_->{speed_in}\n";
      print $fh "$tc_path qdisc add dev \$INTR_IF parent 1:$traf_id_counter handle $traf_id_counter: pfifo limit 100\n";
      print $fh "$tc_path filter add dev \$INTR_IF parent 1:0 protocol ip pref 10 u32 match ip dst $_->{ip} flowid 1:$traf_id_counter\n";
      print $fh "$tc_path class add dev \$EXTR_IF parent 1:10 classid 1:$traf_id_counter htb $_->{speed_out}\n";
      print $fh "$tc_path qdisc add dev \$EXTR_IF parent 1:$traf_id_counter handle $traf_id_counter: pfifo limit 100\n";
      print $fh "$tc_path filter add dev \$EXTR_IF parent 1:0 protocol ip pref 10 u32 match ip src $_->{ip} flowid 1:$traf_id_counter\n";
      #print $fh "EOF\n";
      print $fh "\n";
      $traf_id_counter++;
    }

    $fh->close or die "Can't close tc file: $!";

    return 1;
  });


  # my $err = $app->tcrules_apply()
  # returns 1-success, dies on error
  $app->helper(tcrules_apply => sub {
    my $self = shift;

    # reload rules with script
    my $tcfile = $self->config('tc_file');
    if (!$self->system("INTR_IF=br-lan;EXTR_IF=vpn1;. $tcfile")) {
      return 1; # success
    } else {
      die "Can't apply tc configuration";
    }
  });

}

1;
