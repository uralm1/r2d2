package Head::Plugin::Refresh_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::URL;
use Mojo::IOLoop;


sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # send refresh request to agent
  # $app->refresh_id($agent_url, $client_id);
  $app->helper(refresh_id => sub {
    my ($self, $agent_url, $id) = @_;
    croak 'Bad arguments' unless ($agent_url and $id);

    my $m = "REFRESH client id $id [$agent_url]";
    $self->log->info($m);
    $self->dblog->info($m);

    $self->ua->post(Mojo::URL->new("$agent_url/refresh/$id") =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        if (defined $res) {
          if ($res->is_success) {
            # successful update
            my $m = "Client id $id refresh request successfully received by agent [$agent_url]".($res->body ? ': '.$res->body : '');
            $self->log->info($m);
            $self->dblog->info($m);

          } else {
            # request error 503
            if ($res->is_error) {
              my $m = "Client id $id error: ".$res->body;
              $self->log->error($m);
              $self->dblog->error($m);
            }
          }
        } else {
          # connection to agent failed
          $self->log->error("Connection to agent [$agent_url] failed: $@");
          $self->dblog->error("Client id $id error: connection to agent [$agent_url] failed");
        }

      } # request closure
    );
    return 1;
  });

}


1;
