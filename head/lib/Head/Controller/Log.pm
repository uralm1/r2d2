package Head::Controller::Log;
use Mojo::Base 'Mojolicious::Controller';

sub log {
  my $self = shift;
  my $rsubsys = $self->stash('rsubsys');
  my ($info, $login, $audit);
  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return $self->render(text => 'Invalid JSON request body', status => 415) unless $j;

    $rsubsys = $j->{subsys} if $j->{subsys};
    $info = $j->{info};
    $login = $j->{login} // 'неизвестно';
    $audit = $j->{audit};
    return $self->render(text => 'Bad info in JSON', status => 415) unless defined $info xor defined $audit;

  } else {
    $info = $self->req->text;
    return $self->render(text => 'Bad log info data', status => 415) unless defined $info;
  }

  if (defined $info) {
    $self->app->log->debug("[[$rsubsys]] $info") if $self->config('duplicate_rlogs');
    $self->app->dblog->l(subsys => $rsubsys, info => $info);
  }
  if (defined $audit) {
    $self->app->log->debug("[[user: $login]] $audit") if $self->config('duplicate_rlogs');
    $self->app->dblog->audit($audit, login => $login);
  }

  # empty response on success
  $self->rendered(200);
}


1;
