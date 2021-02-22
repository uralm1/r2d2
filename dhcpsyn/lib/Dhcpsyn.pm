package Dhcpsyn;
use Mojo::Base 'Mojolicious';

use Mojo::File qw(path);
use Mojo::SQLite;
use Dhcpsyn::Command::loadclients;
use Dhcpsyn::Command::dumprules;

#use Carp;
use Sys::Hostname;

our $VERSION = '2.53';

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

  # 1Mb max request
  $self->max_request_size(1048576);

  my $mdb = Mojo::SQLite->new($config->{'minion_db_conn'});
  $mdb->on(connection => sub {
    my ($sql, $dbh) = @_;
    $dbh->do('PRAGMA wal_autocheckpoint=250');
  });
  # don't cache connections on windows, it cause problems with threaded and sqlite
  $mdb->max_connections(0);
  $self->plugin(Minion => { SQLite => $mdb });
  # FIXME DEBUG FIXME: open access to minion UI
  ###$self->plugin('Minion::Admin');

  $self->plugin('Dhcpsyn::Plugin::Utils');
  $self->plugin('Dhcpsyn::Plugin::wdhcp_utils');
  $self->plugin('Dhcpsyn::Plugin::Loadclients_impl');
  $self->plugin('Dhcpsyn::Task::Loadclients');
  $self->plugin('Dhcpsyn::Task::Addreplaceclient');
  $self->plugin('Dhcpsyn::Task::Deleteclient');
  $self->commands->namespaces(['Mojolicious::Command', 'Minion::Command', 'Dhcpsyn::Command']);

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
    $app->rlog("DHCPSYN agent daemon ($VERSION) starting.", sync=>1);

    # load rules on startup
    unless ($config->{disable_autoload}) {
      $app->rlog("Loading and activating clients rules on agent startup.", sync=>1);
      until ($app->check_workers) {
        $app->rlog('Updating clients failed: execution subsystem error.', sync=>1);
        sleep(3);
      }
      $app->minion->enqueue(load_clients => [] => {attempts => 5});
    }
  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->post('/refresh/#id')->to('refresh#refresh');
  $r->post('/runstat')->to('stat#runstat');
}

1;
