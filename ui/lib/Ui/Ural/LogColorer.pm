package Ui::Ural::LogColorer;
use Mojo::Base -base;

# Ural::LogColorer->new();
sub new {
  my $class = shift;
  return bless {
    #colors => [ '#ffdcda', '#fffaca', '#d9ffff', '#f5def9', '#d3ffd5', '#ffffff', '#ececec' ],
    colors => [ '#3f51b5', '#009688', '#303030', '#673ab7', '#7fa554', '#795548', '#ad342b' ],
    d => {},
    next_color => 0,
    #default_color => '#ffffff',
    default_color => '#303030',
  }, $class;
}

# $color_code = $obj->color($str)
sub color {
  my ($self, $str) = @_;

  return $self->{d}{$str} if exists $self->{d}{$str};

  #say "next_color:".$self->{next_color};

  my $c = $self->{colors}[$self->{next_color}++];
  unless ($c) {
    $self->{next_color} = 1;
    $c = $self->{colors}[0] || $self->{default_color};
  }
  return $self->{d}{$str} = $c;
}


1;
