package Dhcpsyn;
use Mojo::Base 'Mojolicious';

use Mojo::File qw(path);
use Dhcpsyn::Command::loadclients;
use Dhcpsyn::Command::dumprules;

#use Carp;
use Sys::Hostname;

our $VERSION = '2.59';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['74567aab492c9873f456fd3ee46713476d45a35'],
    dhcpservers => [],
    dhcpscope => '10.0.0.0',
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

  $self->plugin('Dhcpsyn::Plugin::Utils');
  $self->plugin('Dhcpsyn::Plugin::wdhcp_utils');
  $self->plugin('Dhcpsyn::Plugin::Loadclients_impl');
  $self->plugin('Dhcpsyn::Task::Loadclients');
  $self->plugin('Dhcpsyn::Task::Addreplaceclient');
  $self->plugin('Dhcpsyn::Task::Deleteclient');
  $self->commands->namespaces(['Mojolicious::Command', 'Ljq::Command', 'Dhcpsyn::Command']);

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

    # log startup
    $app->rlog("* DHCPSYN agent daemon ($VERSION) starting.", sync=>1);

    # load rules on startup
    unless ($config->{disable_autoload}) {
      $app->rlog("Loading and activating clients rules on agent startup.", sync=>1);
      until ($app->check_workers) {
        $app->rlog('Updating clients failed: execution subsystem error.', sync=>1);
        sleep(3);
      }
      my $id = $app->ljq->enqueue('load_clients');
      # wait indefinitely until task finishes successfully
      my $state;
      do {
        my $job = $app->ljq->job($id);
        $state = $job->info->{state};
        sleep(3) if $state eq 'inactive' or $state eq 'active';
        if ($state eq 'failed') {
          $app->rlog('Updating clients attempt failed: possibly Head is dead.', sync=>1);
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
