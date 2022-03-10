package Head;
use Mojo::Base 'Mojolicious';

use Head::Command::statprocess;
use Head::Command::cron;
use Head::Command::truncatelog;
use Head::Command::refresh;
use Head::Command::checkdb;
use Head::Command::runstat;
use Head::Command::connectivity;
use Head::Command::block;
use Head::Command::unblock;
use Head::Command::checkclients;

use Sys::Hostname;

our $VERSION = '2.80';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['6ac63578bb604df4865ae802de3098b80c082740'],
    agent_types => [],
    agent_types_stat => [],
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
  $self->plugin('Head::Plugin::Json_schemas');
  $self->plugin('Head::Task::BlockClient');
  $self->plugin('Head::Task::NotifyClient');
  $self->plugin('Head::Task::TrafStat');
  $self->plugin('Head::Task::ProcDaily');
  $self->plugin('Head::Task::ProcMonthly');
  $self->plugin('Head::Task::ProcYearly');
  $self->plugin('Head::Task::TruncateLog');
  $self->plugin('Head::Task::Connectivity');
  $self->plugin('Head::Task::CheckClients');
  $self->plugin('Head::Task::CheckDB');
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

  $r->get('/ui/profiles')->to('ui_system#profileshash');
  $r->get('/ui/profiles/status')->to('ui_system#profilesstatus');
  $r->get('/ui/profiles/list')->to('ui_profiles#list');
  $r->post('/ui/profile')->to('ui_profiles#profilepost');
  $r->get('/ui/profile/#id')->to('ui_profiles#profileget');
  $r->put('/ui/profile/#id')->to('ui_profiles#profileput');
  $r->delete('/ui/profile/#id')->to('ui_profiles#profiledelete');

  $r->get('/ui/agent/#profile_id/#agent_id')->to('ui_agents#agentget');
  $r->put('/ui/agent/#profile_id/#agent_id')->to('ui_agents#agentput');
  $r->delete('/ui/agent/#profile_id/#agent_id')->to('ui_agents#agentdelete');
  $r->post('/ui/agent/#profile_id')->to('ui_agents#agentpost');

  $r->get('/ui/syncqueue/status')->to('ui_system#syncqueuestatus');

  $r->get('/ui/log/oplog')->to('ui_log#oplog');
  $r->get('/ui/log/audit')->to('ui_log#auditlog');

  $r->get('/ui/list')->to('ui_list#list');

  $r->get('/ui/search/0')->to('ui_search#searchclient');
  $r->get('/ui/search/1')->to('ui_search#searchclientbylogin');
  $r->get('/ui/server/#id')->to('ui_servers#serverget');
  $r->put('/ui/server/#id')->to('ui_servers#serverput');
  $r->delete('/ui/server/#id')->to('ui_servers#serverdelete');
  $r->patch('/ui/server/limit/#id')->to('ui_servers#serverpatchlimit');
  $r->post('/ui/server')->to('ui_servers#serverpost');

  $r->post('/ui/client')->to('ui_clients#clientpost');
  $r->get('/ui/client/#id')->to('ui_clients#clientget');
  $r->put('/ui/client/#id')->to('ui_clients#clientput');
  $r->delete('/ui/client/#id')->to('ui_clients#clientdelete');
  $r->patch('/ui/client/0/#id')->to('ui_clients#clientpatch0');
  $r->patch('/ui/client/1/bylogin')->to('ui_clients#clientpatch1bylogin');

  $r->get('/ui/device/#client_id/#device_id')->to('ui_devices#deviceget');
  $r->put('/ui/device/#client_id/#device_id')->to('ui_devices#deviceput');
  $r->delete('/ui/device/#client_id/#device_id')->to('ui_devices#devicedelete');
  $r->patch('/ui/device/move/#client_id/#device_id')->to('ui_devices#devicepatchmove');
  $r->patch('/ui/device/limit/#client_id/#device_id')->to('ui_devices#devicepatchlimit');
  $r->post('/ui/device/#client_id')->to('ui_devices#devicepost');

  $r->get('/ui/stat/device/#client_id/#device_id')->to('ui_stat#deviceget');
  $r->get('/ui/stat/server/#server_id')->to('ui_stat#serverget');
  $r->get('/ui/stat/client/#client_id')->to('ui_stat#clientget');
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

  # agent_types shouldn't be empty
  my $agent_types = $c->{agent_types};
  $e = 'Config parameter agent_types is empty!' unless @$agent_types;

  # agent_types_stat must contain only agent_types elements
  for my $elem (@{$c->{agent_types_stat}}) {
    unless (grep($_ eq $elem, @$agent_types)) {
      $e = 'Config parameter agent_types_stat is invalid!';
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
