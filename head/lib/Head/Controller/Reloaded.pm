package Head::Controller::Reloaded;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub reloaded {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless(@$profs);

  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text=>'Bad json format', status=>503) unless $j;
    my $subsys = $j->{subsys};
    return $self->render(text=>'Bad body parameter', status=>503) unless $subsys;

    my $info = "Agent [$subsys] has finished complete reload.";

    $self->app->log->debug("$info") if $self->config('duplicate_rlogs');
    $self->app->dblog->l(info => $info);

    return $self->rendered(200);

  } else {
    return $self->render(text=>'Unsupported content', status=>503);
  }
}


1;
