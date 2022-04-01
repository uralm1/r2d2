package Ui;
use Mojo::Base 'Mojolicious';

our $VERSION = '1.3';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['4098673ahdde74de78ab0980a098'],
    agent_types => [],
    rt_names => [],
    qs_names => [],
    defjump_names => [],
    speed_plans => [],
    default_limit_in => 2048,
    ipmap_addresses_in_a_line => 30,
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});
  $self->sessions->cookie_name('r2d2ui');
  $self->sessions->default_expiration(0);

  exit 1 unless $self->validate_config;

  $self->max_request_size(16777216);

  $self->plugin('Ui::Plugin::MPagenav');
  $self->plugin('Ui::Plugin::Utils');
  $self->plugin('Ui::Plugin::StatUtils');
  $self->plugin('Ui::Plugin::Html');
  $self->plugin('Ui::Plugin::DeviceFlags');

  #push @{$self->commands->namespaces}, 'Ui::Command';

  $self->defaults(version => $VERSION);

  # set cert/key to useragent (for head requests)
  $self->ua->ca($config->{ca});
  $self->ua->cert($config->{local_cert})->key($config->{local_key});

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
  $r->get('/about/stat')->to('index#aboutstat');

  $r->get('/stat')->to('stat#index');
  $r->post('/stat/email')->to('stat#emailpost');

  $r->get('/status')->to('system#index');

  $r->get('/oplog')->to('log#oplog');
  $r->get('/auditlog')->to('log#auditlog');

  $r->get('/server/new')->to('server#newform');
  $r->post('/server/new')->to('server#newpost');
  $r->get('/server/edit')->to('server#edit');
  $r->post('/server/edit')->to('server#editpost');
  $r->get('/server/delete')->to('server#delete');
  $r->post('/server/delete')->to('server#deletepost');
  $r->get('/server/limit')->to('server#limit');
  $r->post('/server/limit')->to('server#limitpost');
  $r->get('/server/stat')->to('server#stat');

  $r->get('/clients')->to('clients#index');
  $r->get('/client/new')->to('client#newform');
  $r->post('/client/new')->to('client#newpost');
  $r->post('/client/newpain')->to('client#newpainpost');
  $r->get('/client/edit')->to('client#edit');
  $r->post('/client/edit')->to('client#editpost');
  $r->get('/client/replace')->to('client#replace');
  $r->post('/client/replace')->to('client#replacepost');
  $r->get('/client/delete')->to('client#delete');
  $r->post('/client/delete')->to('client#deletepost');
  $r->get('/client/stat')->to('client#stat');

  $r->post('/device/new')->to('device#newpost');
  $r->get('/device/edit')->to('device#edit');
  $r->post('/device/edit')->to('device#editpost');
  $r->get('/device/move')->to('device#move');
  $r->post('/device/move')->to('device#movepost');
  $r->get('/device/delete')->to('device#delete');
  $r->post('/device/delete')->to('device#deletepost');
  $r->get('/device/limit')->to('device#limit');
  $r->post('/device/limit')->to('device#limitpost');
  $r->get('/device/stat')->to('device#stat');

  $r->get('/profiles')->to('profiles#index');
  $r->get('/profile/new')->to('profile#newform');
  $r->post('/profile/new')->to('profile#newpost');
  $r->get('/profile/edit')->to('profile#edit');
  $r->post('/profile/edit')->to('profile#editpost');
  $r->get('/profile/delete')->to('profile#delete');
  $r->post('/profile/delete')->to('profile#deletepost');

  $r->post('/agent/new')->to('agent#newpost');
  $r->get('/agent/edit')->to('agent#edit');
  $r->post('/agent/edit')->to('agent#editpost');
  $r->get('/agent/delete')->to('agent#delete');
  $r->post('/agent/delete')->to('agent#deletepost');

  $r->get('/rep/ipmap')->to('rep#ipmap');
  $r->get('/rep/macdup')->to('rep#macdup');
  $r->get('/rep/leechtop')->to('rep#leechtop');
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

  # agent_types shouldn't be empty
  my $agent_types = $c->{agent_types};
  $e = 'Config parameter agent_types is empty!' unless @$agent_types;

  if ($e) {
    say $e if $self->log->path;
    $self->log->fatal($e);
    return undef;
  }

  1;
}


1;
