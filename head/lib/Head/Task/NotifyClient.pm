package Head::Task::NotifyClient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
use Head::Ural::NotifyClient qw(send_mail_notification retrive_login_limit retrive_ad_fullname_email);
use Carp;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(notify_client => sub {
    my ($job, $id, $qs) = @_;
    croak 'Bad job parameter' unless $id and defined $qs;
    my $app = $job->app;

    #$app->dblog->info("notify_client id=$id task is called!", sync=>1);
    my $str = eval { retrive_login_limit($app, $id) };
    unless ($str) {
      $app->dblog->error("Notify client id $id: $@", sync=>1);
      $job->finish;
      return 0;
    }

    my $str1 = eval { retrive_ad_fullname_email($app, $str->{login}) };
    unless ($str1) {
      $app->dblog->error("Notify client id $id $str->{login}: $@", sync=>1);
      $job->finish;
      return 0;
    }
    unless ($str1->{email}) {
      $app->dblog->error("Notify client id $id $str->{login}: client e-mail is not available", sync=>1);
      $job->finish;
      return 0;
    }
    my $r = eval { send_mail_notification($app, $str1->{email}, $str1->{fullname}, $qs, $str->{limit_in_mb}) };
    unless ($r) {
      $app->dblog->error("Send email error, client id $id: $@", sync=>1);
      $job->finish;
      return 0;
    }

    # set notified flag in DB
    my $results = eval { $app->mysql_inet->db->query("UPDATE clients SET notified = 1 WHERE id = ?", $id) };
    unless ($results) {
      $app->dblog->error("Database notified flag update failed for client id $id", sync=>1);
    } else {
      if ($results->affected_rows > 0) {
        $app->dblog->info("Client id $id notified successfully", sync=>1);
      } else {
        $app->dblog->info("Client id $id notified but nothing is updated", sync=>1);
      }
    }

    $job->finish;
  });
}


1;
