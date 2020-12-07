package Master;
use Mojo::Base 'Mojolicious';

use Master::Command::statprocess;
use Master::Command::cron;
use Master::Command::cleanlog;
use Master::Command::refresh;
use Master::Command::checkdb;
use Master::Ural::Dblog;

use Sys::Hostname;

our $VERSION = '2.50';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['6ac63578bb604df4865ae802de3098b80c082740'],
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  # 1Mb max request
  $self->max_request_size(1048576);

  $self->plugin('Master::Plugin::Utils');
  $self->commands->namespaces(['Mojolicious::Command', 'Master::Command']);

  my $subsys = $self->moniker.'@'.hostname;
  $self->defaults(subsys => $subsys);
  $self->defaults(version => $VERSION);

  $self->defaults(dblog => Master::Ural::Dblog->new($self->mysql_inet->db, subsys=>$subsys));
  unless ($self->defaults('dblog')) {
    die 'Fatal: Database logger creation failure!';
  }

  # use text/plain in most responses
  $self->renderer->default_format('txt');

  # this should run only in server, not with commands
  $self->hook(before_server_start => sub {
    my ($server, $app) = @_;
    
    # log startup
    $app->defaults('dblog')->l(info=>"Master daemon starting ($VERSION).");
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');
  $r->get('/clients')->to('clients#clients');
  $r->get('/client/#id')->to('clients#client');

  $r->post('/log/#rsubsys' => {rsubsys => 'none'})->to('log#log');
}

1;
