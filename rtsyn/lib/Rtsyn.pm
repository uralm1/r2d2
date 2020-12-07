package Rtsyn;
use Mojo::Base 'Mojolicious';

use Mojo::File qw(path);
use Rtsyn::Command::loadrules;
use Rtsyn::Command::printrules;

use Carp;
use Sys::Hostname;

our $VERSION = '2.50';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by config file
  my $config = $self->plugin('Config', { default => {
    secrets => ['94ea91356cc026fa947ba8475dae8573b756c249'],
    iptables_path => '/usr/sbin/iptables',
    iptables_restore_path => '/usr/sbin/iptables-restore',
    client_out_chain => 'pipe_out_inet_clients',
  }});
  delete $self->defaults->{config}; # safety - not to pass passwords to stashes

  # Configure the application
  #$self->mode('production');
  #$self->log->level('info');
  $self->secrets($config->{secrets});

  # 1Mb max request
  $self->max_request_size(1048576);

  $self->plugin('Rtsyn::Plugin::Utils');
  $self->plugin('Rtsyn::Plugin::Loadrules');
  $self->plugin('Rtsyn::Plugin::Rtops');
  $self->commands->namespaces(['Mojolicious::Command', 'Rtsyn::Command']);

  my $subsys = $self->moniker.'@'.hostname;
  $self->defaults(subsys => $subsys);
  $self->defaults(version => $VERSION);

  # use text/plain in most responses
  $self->renderer->default_format('txt');

  # this should run only in server, not with commands
  $self->hook(before_server_start => sub {
    my ($server, $app) = @_;
    
    # log startup
    $app->rlog("Rtsyn agent daemon starting ($VERSION).");

    # load rules on startup
    $app->rlog("Loading and activating clients rules on agent startup");
    unless ($app->load_rules) {
      $app->rlog("Updating rules failed!");
      # TODO reschedule this with timer to repeat later...
    }

  });

  # Router
  my $r = $self->routes;

  $r->get('/subsys')->to('utils#subsys');

  $r->post('/refresh/#id')->to('refresh#refresh');
}

1;
