package Master::Ural::Rtref;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
use Mojo::IOLoop;
use Master::Ural::Dblog;

use Exporter qw(import);
our @EXPORT_OK = qw(rtsyn_refresh_id);

# Master::Ural::Rtref::rtsyn_refresh_id($app, $db, $id, $agent_url);
sub rtsyn_refresh_id {
  my ($app, $db, $id, $agent_url) = @_;
  croak 'Bad one of arguments' unless ($app and $db and $id and $agent_url);

  # update rtsyn
  $app->log->info("Making rtsyn refresh for $id");
  $app->ua->post("$agent_url/refresh/$id" =>
    sub {
      my ($ua, $tx) = @_;
      my $res;
      my $e = eval {
        $res = $tx->result;
      };
      if (defined $e) {
        if ($res->is_success) {
          # successful update
          $app->log->info("Refresh request for $id successful: ".$res->body);
          # remove database flag
          $db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = '0' WHERE clients.id = ? AND clients.login = s.login", $id =>
            sub {
              my ($db, $err, $results) = @_;
              $app->log->error("Database flag update failed for id $id $err") if $err;
            }
          );
        } else {
          # request error 503
          $app->log->error("Refresh request for $id error: ".$res->body) if $res->is_error;
        }
      } else {
        # connection to rtsyn failed
        $app->log->error("Connection to rtsyn failed: $@");
      }

    }
  );
}


1;
