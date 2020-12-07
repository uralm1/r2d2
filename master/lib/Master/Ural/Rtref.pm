package Master::Ural::Rtref;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
use Mojo::IOLoop;
use Master::Ural::Dblog;

use Exporter qw(import);
our @EXPORT_OK = qw(rtsyn_refresh);

# Master::Ural::Rtref::rtsyn_refresh($app);
sub rtsyn_refresh {
  my $app = shift;

  # update rtsyn
  $app->mysql_inet->db->query("SELECT id \
FROM clients, clients_sync s WHERE s.sync_rt = '1' AND clients.login = s.login" =>
    sub {
      my ($db, $err, $results) = @_;
      unless ($err) {
        if (my $rc = $results->hashes) {
          my $ids = $rc->map(sub {$_->{id}}); # id collection
          #say $ids->join(',');
          # send /refresh/id to selected id-s
          my $delay = Mojo::IOLoop->delay;
          my $req;
          $req = sub {
            # stop if there are no more id-s
            return unless my $id = shift @$ids;
            #
            my $end = $delay->begin;

            $app->log->info("Making refresh for $id");
            # url FIXME
            $app->ua->post('http://localhost:3001'."/refresh/$id" =>
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
                    $app->mysql_inet->db->query("UPDATE clients, clients_sync s \
SET s.sync_rt = '0' WHERE id = ? AND clients.login = s.login", $id =>
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

                # next request
                $req->();
                $end->();
              }
            );
          }; # $req coderef

          $req->(); # start first request
          $delay->wait;

        } # database retrival

      } else {
        $app->log->error('Rtsyn refresh: database operation error');
      }

    } # cb
  );
}


1;
