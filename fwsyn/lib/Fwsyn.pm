package Fwsyn;
use Mojo::Base 'Mojolicious';

use Mojo::File qw(path);
use Fwsyn::Command::loaddevices;
use Fwsyn::Command::dumpfiles;
use Fwsyn::Command::dumprules;
use Fwsyn::Command::cron;
use Fwsyn::Command::trafstat;

#use Carp;
use Sys::Hostname;

our $VERSION = '2.62';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['933ac68309daa56ef802aa6754392b88e82000a1'],
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

  exit 1 unless $self->validate_config;

  # 5Mb max request
  $self->max_request_size(5242880);

  $self->plugin(Ljq => { db => $config->{'worker_db_file'} });

  $self->plugin('Fwsyn::Plugin::Utils');
  $self->plugin('Fwsyn::Plugin::fw_utils');
  $self->plugin('Fwsyn::Plugin::tc_utils');
  $self->plugin('Fwsyn::Plugin::Loaddevices_impl');
  $self->plugin('Fwsyn::Plugin::Trafficstat_impl');
  $self->plugin('Fwsyn::Task::Loaddevices');
  $self->plugin('Fwsyn::Task::Addreplacedevice');
  $self->plugin('Fwsyn::Task::Deletedevice');
  $self->plugin('Fwsyn::Task::Blockdevice');
  $self->plugin('Fwsyn::Task::Trafficstat');
  $self->commands->namespaces(['Mojolicious::Command', 'Ljq::Command', 'Fwsyn::Command']);

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
    path($self->config($_))->dirname->make_path for qw/firewall_file tc_file/;

    # log startup
    $app->rlog("* FWSYN agent daemon ($VERSION) starting.", sync=>1);

    # load clients data on startup
    unless ($config->{disable_autoload}) {
      $app->rlog('Loading and activating devices on agent startup', sync=>1);
      until ($app->check_workers) {
        $app->rlog('Updating devices failed: execution subsystem error.', sync=>1);
        sleep(3);
      }
      my $id = $app->ljq->enqueue('load_devices');
      # wait indefinitely until task finishes successfully
      my $state;
      do {
        my $job = $app->ljq->job($id);
        $state = $job->info->{state};
        sleep(3) if $state eq 'inactive' or $state eq 'active';
        if ($state eq 'failed') {
          $app->rlog('Updating devices attempt failed: possibly Head is dead.', sync=>1);
          sleep(5);
          $job->retry;
        }
      } until $state eq 'finished';
    }
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->post('/refresh/#id')->to('refresh#refresh');
  $r->post('/runstat')->to('stat#runstat');
  $r->post('/block/#id/#qs')->to('block#block');
  $r->post('/reload')->to('reload#reload');
}


sub validate_config {
  my $self = shift;
  my $c = $self->config;

  my $e = undef;
  for (qw/my_profiles/) {
    if (!$c->{$_} || ref($c->{$_}) ne 'ARRAY') {
      $e = "Config parameter $_ is not defined or not ARRAY!";
    }
    last;
  }

  if ($e) {
    say $e if $self->log->path;
    $self->log->fatal($e);
    return undef;
  }
  1;
}

1;
