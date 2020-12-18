package Gwsyn::Controller::Refresh;
use Mojo::Base 'Mojolicious::Controller';

sub refresh {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status=>503) unless (defined($id) && $id =~ /^\d+$/);

  $self->render_later;

  # request client record, continue in cb
  $self->ua->get($self->config('head_url')."/client/$id" =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval {
        $tx->result;
      };
      if (defined $res) {
        if ($res->is_success) {
          my $v = $res->json;
          if ($v) {
            # add or update
            # actual data returned $v
            #my $e = eval { $self->rt_add_replace($v) };
            #if (defined $e) {
            #  return $self->render(text => $e);
            #} else {
            #  return $self->render(text=>$@, status=>503);
            #}
            return $self->render(text => "WORKING!!!");

          } else {
            return $self->render(text=>"Client response json error", status=>503);
          }
        } else {
          if ($res->code == 404) {
            # delete not found client $id
            #my $e = eval { $self->rt_delete($id) };
            #if (defined $e) {
            #  return $self->render(text => $e);
            #} else {
            #  return $self->render(text=>$@, status=>503);
            #}
            return $self->render(text => "WORKING!!!");
          }
          return $self->render(text=>"Client request error: ".$res->body, status=>503) if $res->is_error;
        }
      } else {
        return $self->render(text=>"Connection to head failed: $@", status=>503);
      }
    }
  );
}


1;
