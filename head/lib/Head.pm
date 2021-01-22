package Head;
use Mojo::Base 'Mojolicious';

use Head::Command::statprocess;
use Head::Command::cron;
use Head::Command::rotatelog;
use Head::Command::refresh;
use Head::Command::checkdb;
use Head::Command::runstat;
use Head::Ural::Dblog;

use Sys::Hostname;

our $VERSION = '2.52';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['6ac63578bb604df4865ae802de3098b80c082740'],
    duplicate_rlogs => 0,
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  # 1Mb max request
  $self->max_request_size(1048576);

  $self->plugin('Head::Plugin::Utils');
  $self->plugin('Head::Plugin::Refresh_impl');
  $self->commands->namespaces(['Mojolicious::Command', 'Head::Command']);

  my $subsys = $self->moniker.'@'.hostname;
  $self->defaults(subsys => $subsys);
  $self->defaults(version => $VERSION);

  $self->defaults(dblog => Head::Ural::Dblog->new($self->mysql_inet, subsys=>$subsys));
  unless ($self->defaults('dblog')) {
    die 'Fatal: Database logger creation failure!';
  }

  # use text/plain in most responses
  $self->renderer->default_format('txt');

  # set cert/key to useragent
  $self->ua->ca($config->{ca});
  $self->ua->cert($config->{local_cert})->key($config->{local_key});

  # this should run only in server, not with commands
  $self->hook(before_server_start => sub {
    my ($server, $app) = @_;

    # log startup
    $app->defaults('dblog')->l(info=>"Head of R2D2 ($VERSION) starting.");
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->get('/clients/#profile')->to('clients#clients');
  $r->get('/client/#id')->to('clients#client');
  $r->post('/trafstat/#profile')->to('stat#trafstat');

  $r->post('/log/#rsubsys' => {rsubsys => 'none'})->to('log#log');
}

1;
