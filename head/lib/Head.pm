package Head;
use Mojo::Base 'Mojolicious';

use Head::Command::statprocess;
use Head::Command::cron;
use Head::Command::truncatelog;
use Head::Command::refresh;
use Head::Command::checkdb;
use Head::Command::checkdbdel;
use Head::Command::runstat;
use Head::Command::connectivity;
use Head::Command::block;
use Head::Command::unblock;

use Sys::Hostname;

our $VERSION = '2.71';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['6ac63578bb604df4865ae802de3098b80c082740'],
    delcheck_compat_file => 'compat_chk.dat',
    agent_types_stat => [],
    profiles => {},
    duplicate_rlogs => 0,
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  exit 1 unless $self->validate_config;

  # 5Mb max request
  $self->max_request_size(5242880);

  $self->plugin(Minion => {mysql => $config->{minion_db_conn}});
  # FIXME DEBUG FIXME: open access to minion UI
  ##$self->plugin('Minion::Admin');

  $self->plugin('Head::Plugin::Utils');
  $self->plugin('Head::Plugin::Migrations');
  $self->plugin('Head::Plugin::Refresh_impl');
  $self->plugin('Head::Plugin::Json_schemas');
  $self->plugin('Head::Task::BlockClient');
  $self->plugin('Head::Task::NotifyClient');
  $self->plugin('Head::Task::TrafStat');
  $self->plugin('Head::Task::ProcDaily');
  $self->plugin('Head::Task::ProcMonthly');
  $self->plugin('Head::Task::ProcYearly');
  $self->plugin('Head::Task::TruncateLog');
  $self->commands->namespaces(['Mojolicious::Command', 'Minion::Command', 'Head::Command']);

  my $subsys = $self->moniker.'@'.hostname;
  $self->defaults(subsys => $subsys);
  $self->defaults(version => $VERSION);

  # update database
  $self->migrate_database;

  # use text/plain in most responses
  $self->renderer->default_format('txt');

  # set cert/key to useragent
  $self->ua->ca($config->{ca});
  $self->ua->cert($config->{local_cert})->key($config->{local_key});

  # this should run only in server, not with commands
  $self->hook(before_server_start => sub {
    my ($server, $app) = @_;

    # log startup
    $app->dblog->l(info=>"* Head of R2D2 ($VERSION) starting.", sync=>1);
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->get('/clients')->to('devices#devices'); # DEPRECATED
  $r->get('/devices')->to('devices#devices');
  $r->get('/client/#id')->to('devices#device'); # DEPRECATED
  $r->get('/device/#id')->to('devices#device');
  $r->post('/trafstat')->to('stat#trafstat');
  $r->post('/refreshed')->to('refreshed#refreshed');
  $r->post('/blocked')->to('blocked#blocked');
  $r->post('/reloaded')->to('reloaded#reloaded');

  $r->post('/log/#rsubsys' => {rsubsys => 'none'})->to('log#log');

  $r->get('/ui/oplog')->to('ui_oplog#oplog');
  $r->get('/ui/list')->to('ui_list#list');
  $r->get('/ui/servers')->to('ui_servers#servers');
  $r->get('/ui/server/#id')->to('ui_servers#serverget');
  $r->put('/ui/server/#id')->to('ui_servers#serverput');
  $r->delete('/ui/server/#id')->to('ui_servers#serverdelete');
  $r->post('/ui/server')->to('ui_servers#serverpost');
  $r->post('/ui/client')->to('ui_clients#clientpost');
}


sub validate_config {
  my $self = shift;
  my $c = $self->config;

  my $e = undef;
  for (qw/smtp_host mail_from/) {
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
