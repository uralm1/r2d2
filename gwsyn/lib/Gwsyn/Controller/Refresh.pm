package Gwsyn::Controller::Refresh;
use Mojo::Base 'Mojolicious::Controller';

sub refresh {
  my $self = shift;
  my $id = $self->stash('id');
  return $self->render(text=>'Bad parameter', status=>503) unless (defined($id) && $id =~ /^\d+$/);

  unless ($self->check_workers) {
    $self->rlog('Error refreshing client. Execution subsystem error.');
    return $self->render(text=>'Error refreshing client, execution impossible', status=>503);
  }

  $self->render_later;

  my $prof = $self->config('my_profile');
  # request client record, continue in cb
  $self->ua->get($self->config('head_url')."/client/$id" =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text=>"Connection to head failed: $@", status=>503) unless defined $res;

      if ($res->is_success) {
        my $v = $res->json;
        return $self->render(text=>"Client response json error", status=>503) unless $v;

        if ($v->{profile} && $v->{profile} eq $prof) {
          # add or update
          # actual data returned in $v
          $self->minion->enqueue('addreplace_client' => [$v]);

        } else { # not our profile
          # try to delete client $id
          $self->minion->enqueue('delete_client' => [$id]);
        }
        return $self->rendered(200);

      } elsif ($res->code == 404) {
        # delete not found client $id
        $self->minion->enqueue('delete_client' => [$id]);
        return $self->rendered(200);

      } else {
        return $self->render(text=>"Client request error: ".(($res->is_error) ? substr($res->body, 0, 40) : 'none'), status=>503);
      }
    } # closure
  );
}


1;
