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


# internal, starts asyncronious submit process
sub _submit_traf_stats {
  my ($self, $prof, $j) = @_;
  croak 'Bad parameter' unless $j or $prof;

  say $self->dumper($j);
  # first retrive database values for requested profile
  $self->mysql_inet->db->query("SELECT id, sum_in, sum_out, qs, sum_limit_in \
FROM clients WHERE profile = ?", $prof =>
    sub {
      my ($db, $err, $results) = @_;
      if ($err) {
        $self->log->error($err);
        return $self->render(text=>'Database failure', status=>503);
      }

      if (my $rc = $results->hashes) {
        my $db_hash = $rc->reduce(sub { $a->{$b->{id}} = $b; $a }, {});
        say $self->dumper($db_hash);

        while (my ($id, $v) = each %$j) {
          if (exists $db_hash->{$id}) {
            my $db_rec = $db_hash->{$id};
            my $inb = $v->{in};
            my $outb = $v->{out};

            if ($inb > 0) {
              $db_rec->{sum_in} += $inb;
              if ($db_rec->{qs} != 0) { # don't calc limit when quota is disabled
                $db_rec->{sum_limit_in} -= $inb;
                $db_rec->{sum_limit_in} = 0 if $db_rec->{sum_limit_in} < 0;
              }
            }

            if ($outb > 0) {
              $db_rec->{sum_out} += $outb;
            }

            $self->mysql_inet->db->query("UPDATE clients SET sum_in = ?, sum_out = ?, sum_limit_in = ? \
WHERE id = ?", $db_rec->{sum_in}, $db_rec->{sum_out}, $db_rec->{sum_limit_in}, $id =>
              sub {
                my ($db, $err, $results) = @_;
                if ($err) {
                  $self->log->error($err);
                  return $self->render(text=>'Database update failure', status=>503);
                }
              } # db UPDATE closure
            ) if $inb > 0 or $outb >0;
          }
        } # loop by submitted ids
        return $self->rendered(200); # SUCCESS

      } else {
        return $self->render(text=>'Nothing is accepted', status=>200);
      }
    } # first db SELECT closure
  );

  1;
}


1;
