package Gwsyn;
use Mojo::Base 'Mojolicious';

use Mojo::File qw(path);
use Gwsyn::Command::loadclients;
use Gwsyn::Command::dumpfiles;
use Gwsyn::Command::dumprules;
use Gwsyn::Command::cron;
use Gwsyn::Command::trafstat;

#use Carp;
use Sys::Hostname;

our $VERSION = '2.52';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['867da09855bcd84ff800ea38505a0b75c7399d32'],
    iptables_path => '/usr/sbin/iptables',
    iptables_restore_path => '/usr/sbin/iptables-restore',
    tc_path => '/usr/sbin/tc',
    client_in_chain => 'pipe_in_inet_clients',
    client_out_chain => 'pipe_out_inet_clients',
    rlog_remote => 1,
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  # 1Mb max request
  $self->max_request_size(1048576);

  $self->plugin(Minion => {SQLite => $config->{'minion_db_conn'}});
  # FIXME DEBUG FIXME: open access to minion UI
  ###$self->plugin('Minion::Admin');

  $self->plugin('Gwsyn::Plugin::Utils');
  $self->plugin('Gwsyn::Plugin::dhcp_utils');
  $self->plugin('Gwsyn::Plugin::fw_utils');
  $self->plugin('Gwsyn::Plugin::tc_utils');
  $self->plugin('Gwsyn::Plugin::Loadclients_impl');
  $self->plugin('Gwsyn::Task::Loadclients');
  $self->plugin('Gwsyn::Task::Addreplaceclient');
  $self->plugin('Gwsyn::Task::Deleteclient');
  $self->plugin('Gwsyn::Task::Trafficstat');
  $self->commands->namespaces(['Mojolicious::Command', 'Minion::Command', 'Gwsyn::Command']);

  $self->defaults(subsys => $self->moniker.'@'.hostname);
  $self->defaults(version => $VERSION);

  # use text/plain in most responses
  $self->renderer->default_format('txt');

  # set cert/key to useragent
  $self->ua->ca($config->{ca});
  $self->ua->cert($config->{local_cert})->key($config->{local_key});

  # this should run only in server, not with commands
  $self->hook(before_server_start => sub {
    my ($server, $app) = @_;

    # create dirs
    path($self->config($_))->dirname->make_path for qw/dhcphosts_file firewall_file tc_file/;

    # log startup
    $app->rlog("Gwsyn agent daemon ($VERSION) starting.");

    # load clients data on startup
    unless ($config->{disable_autoload}) {
      $app->rlog('Loading and activating clients on agent startup');
      until ($app->check_workers) {
        $app->rlog('Updating clients failed: execution subsystem error.');
        sleep(3);
      }
      $app->minion->enqueue('load_clients' => {attempts => 5});
    }
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->post('/refresh/#id')->to('refresh#refresh');
}

1;