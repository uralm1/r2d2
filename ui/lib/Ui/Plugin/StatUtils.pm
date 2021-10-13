package Ui::Plugin::StatUtils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::Util qw(xml_escape);
use Mojo::ByteStream 'b';

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # "1.1 Мб" = traftomb(1024)
  # "н/д" = traftomb(-1)
  $app->helper(traftomb => sub {
    my $b = $_[1];
    return 'н/д' if $b < 0;
    return $_[0]->btomb($b).' Мб';
  });


  # "<td>~1.1 Мб (~1024 байт)</td><td>н/д</td>" = traftotd({in=>1024,out=>-1,fuzzy_in=>1})
  $app->helper(traftotd => sub {
    my $self = $_[0];
    my $t = $_[1];
    my $r = '';
    for (qw/in out/) {
      my $b = $t->{$_};
      if (!defined $b || $b < 0) {
        $r .= '<td>н/д</td>';
      } else {
        my $fuz = $t->{"fuzzy_$_"} ? '~' : '';
        $r .= '<td>'.xml_escape($fuz.$self->btomb($b)." Мб ($fuz$b байт)").'</td>';
      }
    }
    return b( $r );
  });


  $app->helper(datetotd => sub {
    if ($_[1] =~ /^(\d+)[-\/](\d+)[-\/](\d+)$/) {
      return b( '<td>'.xml_escape( $_[2] ? "$2-$3" : "$1-$2-$3" ).'</td>' );
    }
    return b( '<td>н/д</td>' );
  });


  $app->helper(get_js_date => sub {
    if ($_[1] =~ /^(\d+)[-\/](\d+)[-\/](\d+)$/) {
      my $m = $2 - 1;
      return "new Date($3,$m,$1)";
    }
    return undef;
  });


  $app->helper(days_in => sub {
    my ($self, $year, $month) = @_;
    # $month is 0..11
    #               1  2  3  4  5  6  7  8  9 10 11 12
    my @mltable = (31, 0,31,30,31,60,31,31,30,31,30,31);
    return $mltable[$month] unless $month == 2;
    return 28 unless $self->is_leap($year);
    return 29;
  });


  $app->helper(is_leap => sub {
    my $y = $_[1];
    return ( ($y % 4 == 0) and ($y % 400 == 0 or $y % 100 != 0) ) || 0;
  });

}

1;
