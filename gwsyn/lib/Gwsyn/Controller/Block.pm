package Gwsyn::Controller::Block;
use Mojo::Base 'Mojolicious::Controller';


sub block {
  my $self = shift;
  my $id = $self->stash('id');
  my $qs = $self->stash('qs');
  return $self->render(text=>'Bad parameter', status=>503) unless (defined($id) && $id =~ /^\d+$/ &&
    defined($qs) && $qs =~ /^[023]$/);

  unless ($self->check_workers) {
    $self->rlog('Error blocking/unblocking client. Execution subsystem error.');
    return $self->render(text=>'Error blocking/unblocking client, execution impossible', status=>503);
  }

  $self->minion->enqueue('block_client' => [$id, $qs]);
  return $self->rendered(200);
}


1;
