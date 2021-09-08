package Head::Controller::Reloaded;
use Mojo::Base 'Mojolicious::Controller';

use Carp;

sub reloaded {
  my $self = shift;
  my $profs = $self->req->query_params->every_param('profile');
  croak 'Bad parameter' unless $profs;
  # at least one profile parameter is required
  return $self->render(text=>'Bad parameter', status=>503) unless(@$profs);

  return unless my $j = $self->json_content($self->req);
  my $subsys = $j->{subsys};
  return $self->render(text=>'Bad body parameter', status=>503) unless $subsys;

  my $info = "Agent [$subsys] has finished complete reload.";

  $self->app->log->debug("$info") if $self->config('duplicate_rlogs');
  $self->app->dblog->l(info => $info);

  return $self->rendered(200);
}


1;
