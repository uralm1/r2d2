package Gwsyn::Controller::Refresh;
use Mojo::Base 'Mojolicious::Controller';

sub refresh {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status=>503) unless (defined($id) && $id =~ /^\d+$/);

  unless ($self->check_workers) {
    $self->rlog('Error adding/replacing client. Execution subsystem error.');
    return $self->render(text=>'Error adding/replacing client, execution impossible', status=>503);
  }

  $self->render_later;

  my $prof = $self->config('my_profile');
  # request client record, continue in cb
  $self->ua->get($self->config('head_url')."/client/$id" =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      if (defined $res) {
        if ($res->is_success) {
          my $v = $res->json;
          if ($v) {
            if ($v->{profile} && $v->{profile} eq $prof) {
              # add or update
              # actual data returned in $v
              $self->minion->enqueue('addreplace_client' => [$v]);
              return $self->rendered(200);

            } else { # not our profile
              # try to delete client $id
              $self->minion->enqueue('delete_client' => [$id]);
              return $self->rendered(200);

            }

          } else {
            return $self->render(text=>"Client response json error", status=>503);
          }
        } else {
          if ($res->code == 404) {
            # delete not found client $id
            $self->minion->enqueue('delete_client' => [$id]);
            return $self->rendered(200);

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
