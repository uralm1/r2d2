package Head::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub trafstat {
  my $self = shift;
  my $prof = $self->stash('profile');
  return $self->render(text=>'Bad parameter', status=>503) unless $prof;

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j;

    $self->render_later;
    $self->_submit_traf_stats($prof, $j);

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


# internal, starts syncronious submit process
sub _submit_traf_stats {
  my ($self, $prof, $j) = @_;
  croak 'Bad parameter' unless $j or $prof;

  say $self->dumper($j);

  # update database in single transaction
  my $db = $self->mysql_inet->db;
  eval {
    my $tx = $db->begin;

    while (my ($id, $v) = each %$j) {
      my $inb = $v->{in};
      my $outb = $v->{out};

      if ($inb > 0 or $outb > 0) {
        my $res = $db->query("UPDATE clients SET sum_in = sum_in + ?, sum_out = sum_out + ?, \
sum_limit_in = IF(qs != 0, IF(sum_limit_in > ?, sum_limit_in - ?, 0), sum_limit_in) \
WHERE profile = ? AND id = ?", $inb, $outb, $inb, $inb, $prof, $id);
      }

    } # loop by submitted ids
    $tx->commit;
  };
  if ($@) {
    $self->log->error("Database update failure: $@");
    return $self->render(text=>"Database update failure", status=>503);
  }

  return $self->rendered(200); # SUCCESS
}


1;
