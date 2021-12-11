package Ui::Plugin::DeviceFlags;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # 0/1 = dev_flagged($device_rec_hash)
  $app->helper(dev_flagged => sub {
    ($_[1] // $_)->{flagged}
  });

  # 0/1 = dev_blocked($device_rec_hash)
  $app->helper(dev_blocked => sub {
    ($_[1] // $_)->{blocked}
  });

  # 0/1 = dev_warnedorblocked($device_rec_hash)
  $app->helper(dev_warnedorblocked => sub {
    my $r = $_[1] // $_;
    return ($r->{sum_limit_in} <= 0 && $r->{qs} != 0) || $r->{blocked};
  });

  # 0/1 = anydev_warnedorblocked(\@devices_rec_array)
  $app->helper(anydev_warnedorblocked => sub {
    return scalar grep {($_->{sum_limit_in} <= 0 && $_->{qs} != 0) || $_->{blocked}} @{$_[1]};
  });

}

1;
