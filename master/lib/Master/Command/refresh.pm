package Master::Command::refresh;
use Mojo::Base 'Mojolicious::Command';

use Carp;

has description => '* Manually refresh client by id';
has usage => "Usage: APPLICATION refresh <client-id>\n";

sub run {
  my ($self, $id) = @_;
  my $app = $self->app;
  croak("Bad argument\n") unless (defined($id) && $id =~ /^\d+$/);

  # send refresh request to rtsyn (blocking)
  my $res;
  my $e = eval {
    my $tx = $app->ua->post("http://localhost:3001/refresh/$id");
    $res = $tx->result;
  };
  if (defined $e) {
    if ($res->is_success) {
      $app->log->info('Refresh request successfully sent.');
      say $res->body;
    } else {
      $app->log->error('Refresh request error: '.$res->body) if ($res->is_error);
    }
  } else {
    $app->log->error("Refresh: connection to rtsyn failed: $@");
  }
  return 0; # error
}

1;
