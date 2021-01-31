package Head::Plugin::Refresh_impl;
use Mojo::Base 'Mojolicious::Plugin';

use Carp;
use Mojo::mysql;
use Mojo::IOLoop;
use Head::Ural::Dblog;


sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};


  # send refresh request to agent
  # $app->refresh_id($agent_url, $client_id, sub { my ($self, $id) = @_; database flag update code });
  $app->helper(refresh_id => sub {
    my ($self, $agent_url, $id, $upd_flag_sub) = @_;
    croak 'Bad arguments' unless ($agent_url and $id and $upd_flag_sub and ref($upd_flag_sub) eq 'CODE');

    $self->ua->post("$agent_url/refresh/$id" =>
      sub {
        my ($ua, $tx) = @_;
        my $res = eval { $tx->result };
        if (defined $res) {
          if ($res->is_success) {
            # successful update
            my $m = "Client id $id refresh successful".($res->body ? ': '.$res->body : '');
            $self->log->info($m);
            $self->stash('dblog')->l(info => $m);

            $upd_flag_sub->($self, $id);

          } else {
            # request error 503
            if ($res->is_error) {
              my $m = "Client id $id error: ".$res->body;
              $self->log->error($m);
              $self->stash('dblog')->l(info => $m);
            }
          }
        } else {
          # connection to agent failed
          $self->log->error("Connection to agent failed: $@");
          $self->stash('dblog')->l(info => "Client id $id error: connection to agent failed");
        }

      } # request closure
    );
    return 1;
  });


  # $app->refresh_id_bytype($agent_type, $agent_url, $client_id);
  $app->helper(refresh_id_bytype => sub {
    my ($self, $agent_type, $agent_url, $id) = @_;
    croak 'Undefined <agent_type> argument' unless defined $agent_type;

    my $m = "REFRESH client id $id $agent_type $agent_url";

    # RTSYN
    if ($agent_type eq 'rtsyn') {
      $self->log->info($m);
      $self->stash('dblog')->l(info => $m);

      $self->refresh_id($agent_url, $id, sub {
        my ($self, $id) = @_;

        my $db = $self->mysql_inet->db;
        $db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = '0' WHERE clients.id = ? AND clients.login = s.login", $id =>
          sub {
            my ($db, $err, $results) = @_;
            if ($err) {
              my $m = "Database sync_rt flag update failed for client id $id";
              $self->log->error("$m: $err");
              $self->stash('dblog')->l(info => $m);
            }
          }
        );
      });

    # DHCPSYN
    } elsif ($agent_type eq 'dhcpsyn') {
      $app->log->warn("Not implemented!");
      #TODO

    # FWSYN
    } elsif ($agent_type eq 'fwsyn') {
      $app->log->warn("Not implemented!");
      #TODO

    # GWSYN
    } elsif ($agent_type eq 'gwsyn') {
      $self->log->info($m);
      $self->stash('dblog')->l(info => $m);

      $self->refresh_id($agent_url, $id, sub {
        my ($self, $id) = @_;

        my $db = $self->mysql_inet->db;
        $db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = 0, s.sync_dhcp = 0, s.sync_fw = 0 WHERE clients.id = ? AND clients.login = s.login", $id =>
          sub {
            my ($db, $err, $results) = @_;
            if ($err) {
              my $m = "Database sync_fw/rt/dhcp flags update failed for client id $id";
              $self->log->error("$m: $err");
              $self->stash('dblog')->l(info => $m);
            }
          }
        );
      });

    } else {
      my $m = "Skipped client id $id: unsupported agent $agent_type!";
      $app->log->warn($m);
      $self->stash('dblog')->l(info => $m);
    }
    # end of switch by agent_type

  });

}


1;
