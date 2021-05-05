package Ui;
use Mojo::Base 'Mojolicious';

our $VERSION = '0.2';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['4098673ahdde74de78ab0980a098'],
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  exit 1 unless $self->validate_config;

  $self->max_request_size(16777216);

  $self->plugin('Ui::Plugin::MPagenav');
  $self->plugin('Ui::Plugin::Utils');

  #push @{$self->commands->namespaces}, 'Ui::Command';

  $self->defaults(version => $VERSION);

  # Router authentication routine
  $self->hook(before_dispatch => sub {
    my $c = shift;

    my $remote_user;
    my $ah = $c->config('auth_user_header');
    if ($ah) {
      $remote_user = lc($c->req->headers->header($ah));
    } else {
      $remote_user = lc($c->req->env('REMOTE_USER'));
    }
    #FIXME DEBUG FIXME
    $remote_user = 'ural';

    unless ($remote_user) {
      $c->render(text => 'Необходима аутентификация', status => 401);
      return undef;
    }
    $c->stash(remote_user => $remote_user);
    $c->stash(remote_user_role => $c->get_user_role($remote_user));
    unless ($c->stash('remote_user_role')) {
      $c->render(text => 'Неверный пользователь', status => 401);
      return undef;
    }

    return 1;
  });

  # Router
  my $r = $self->routes;

  $r->get('/')->to('index#index');
  $r->get('/about')->to('index#about');

  $r->get('/rep/users')->to('rep#users');

  $r->get('/oplog')->to('oplog#index');
}


sub validate_config {
  my $self = shift;
  my $c = $self->config;

  my $e = undef;
  for (qw//) {
    unless ($c->{$_}) {
      $e = "Config parameter $_ is not defined!";
      last;
    }
  }

  if ($e) {
    say $e if $self->log->path;
    $self->log->fatal($e);
    return undef;
  }
  1;
}


1;
