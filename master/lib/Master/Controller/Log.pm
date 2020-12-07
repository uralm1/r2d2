package Master::Controller::Log;
use Mojo::Base 'Mojolicious::Controller';

use Master::Ural::Dblog;

sub log {
  my $self = shift;
  my $rsubsys = $self->stash('rsubsys');
  my $info;
  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Invalid JSON request body', status=>415) unless $j;

    $rsubsys = $j->{subsys} if $j->{subsys};
    $info = $j->{info};
    return $self->render(text=>'Bad info in JSON', status=>415) unless defined $info;
  } else {
    $info = $self->req->text;
    return $self->render(text=>'Bad log info data', status=>415) unless defined $info;
  }

  $self->stash('dblog')->l(subsys => $rsubsys, info => $info);

  # empty response on success
  $self->rendered(200);
}


1;
