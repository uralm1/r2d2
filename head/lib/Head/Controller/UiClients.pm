package Head::Controller::UiClients;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::mysql;


# new client submit
sub clientpost {
  my $self = shift;
  my $fmt = $self->req->headers->content_type // '';
  if ($fmt =~ m#^application/json$#i) {
    my $j = $self->req->json;
    return unless $self->json_validate($j, 'client_record');

    return $self->render(text => 'Bad id', status => 503) if exists($j->{id});

    $self->log->debug($self->dumper($j));
    $self->render_later;

    $self->mysql_inet->db->query("INSERT INTO clients \
(create_time, guid, login, clients.desc, cn, email, lost) \
VALUES (NOW(), ?, ?, ?, ?, ?, 0)",
      $j->{guid},
      $j->{login},
      $j->{desc},
      $j->{cn},
      $j->{email} =>
      sub {
        my ($db, $err, $results) = @_;
        return $self->render(text => "Database error, inserting client: $err", status => 503) if $err;

        my $last_id = $results->last_insert_id;
        $self->dblog->info("UI: Client id $last_id added successfully");
        $self->render(text => $last_id);
      }
    );

  } else {
    return $self->render(text => 'Unsupported content', status => 503);
  }
}


1;
