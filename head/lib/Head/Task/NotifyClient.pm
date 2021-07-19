package Head::Task::NotifyClient;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;
use Head::Ural::NotifyClient qw(send_mail_notification retrive_login_db_attr retrive_ad_fullname_email);

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(notify_client => sub {
    my ($job, $id, $doing_unblock) = @_;
    die 'Bad job parameter' unless $id;
    # $doing_unblock is optional parameter flag
    my $app = $job->app;

    #$app->dblog->info("notify_client id=$id task is called!", sync=>1);
    my $str = eval { retrive_login_db_attr($app, $id) };
    unless ($str) {
      chomp $@;
      $app->dblog->error("Notify device id $id: $@", sync=>1);
      $job->finish;
      return 0;
    }
    # $str->{notified}; # don't check this flag here, the task is always notify device

    my $str1 = eval { retrive_ad_fullname_email($app, $str->{login}) };
    unless ($str1) {
      chomp $@;
      $app->dblog->error("Notify device id $id $str->{login}: $@", sync=>1);
      _set_notified_flag($app, $id) if $@ =~ /^No data from/; # stop notifications for this device
      $job->finish;
      return 0;
    }
    unless ($str1->{email}) {
      $app->dblog->error("Notify device id $id $str->{login}: client e-mail is not available", sync=>1);
      _set_notified_flag($app, $id); # stop notifications for this device
      $job->finish;
      return 0;
    }
    my $qs_op = ($doing_unblock) ? 0 : $str->{qs};
    my $r = eval { send_mail_notification($app, $str1->{email}, $str1->{fullname}, $qs_op, $str->{limit_in_mb}) };
    unless ($r) {
      chomp $@;
      $app->dblog->error("Send email error, device id $id: $@", sync=>1);
      $job->finish;
      return 0;
    }

    # set notified flag in DB
    _set_notified_flag($app, $id);

    $job->finish;
  });
}


# _set_notified_flag($job->app, $id)
sub _set_notified_flag {
  my ($app, $id) = @_;

  my $results = eval { $app->mysql_inet->db->query("UPDATE devices SET notified = 1 WHERE id = ?", $id) };
  if ($results) {
    if ($results->affected_rows > 0) {
      $app->dblog->info("Device id $id notified successfully", sync=>1);
    } else {
      $app->dblog->info("Device id $id notified but nothing is updated", sync=>1);
    }
  } else {
    $app->dblog->error("Database notified flag update failed for device id $id", sync=>1);
  }
}


1;
