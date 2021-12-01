package Head::Ural::NotifyClient;
use Mojo::Base -base;

use Mojo::mysql;
use Mojo::Loader qw(data_section load_class);
use Net::SMTP;
use Net::Domain qw(hostfqdn);
use Encode;
#use Carp;
#use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail_notification retrive_db_attr);


# send_mail_notification($app, $client_email, $client_cn, $device_name, $device_qs, $device_limit_mb)
# all parameters are mandatory,
# die with error message on errors
sub send_mail_notification {
  my ($app, $to, $cn, $device_name, $qs, $limit_mb) = @_;
  $limit_mb //= '---';

  my $mail_from = $app->config('mail_from');
  my $mf_name = $app->config('mail_from_name');

  load_class 'mail_templates';
  my $template = data_section 'mail_templates', "mail$qs";
  die "Mail error. Can't retrieve mail template\n" unless $template;
  $template = decode_utf8($template);

  # fill mail template
  my %repl = (
    MAILFROM => $mf_name ? '"'.encode('MIME-Header', $mf_name)."\" <$mail_from>" : $mail_from,
    CLIENTNAME => $cn,
    CLIENTEMAIL => $to,
    DEVICENAME => $device_name,
    DEVICELIMIT => $limit_mb,
  );
  $template =~ s/%%$_%%/$repl{$_}/g for (keys %repl);

  my @content = map { encode_utf8($_) } split /^/, $template;

  # send mail
  my $smtp = Net::SMTP->new($app->config('smtp_host'), Hello => hostfqdn() // 'r2d2.domainname', Timeout => 10, Debug => 0) or
    die 'Mail error. Create smtp object failed';

  unless ($smtp->mail($mail_from)) {
    $smtp->quit;
    die "Mail error. Mail command failed\n";
  }
  unless ($smtp->to($to)) {
    $smtp->quit;
    die "Mail error. Rcpt command failed\n";
  }
  unless ($smtp->data(@content)) {
    $smtp->quit;
    die "Mail error. Data command failed\n";
  }
  $smtp->quit;
  return 1;
}


# $str = retrive_db_attr($app, $id)
# $str = { 
#   cn => 'FIO/ServerName',
#   login => 'login',
#   email => 'user@server',
#   device_name => 'working station',
#   limit_in_mb => 12345,
#   qs => 1,
#   notified => 0
# }
# die with error message on errors
sub retrive_db_attr {
  my ($app, $id) = @_;

  my $str = undef;
  my $e = eval {
    my $results = $app->mysql_inet->db->query("SELECT c.cn, c.login, c.email, d.name, limit_in, qs, notified \
FROM devices d INNER JOIN clients c ON d.client_id = c.id WHERE d.id = ?", $id);
    if (my $n = $results->hash) {
      $str->{cn} = $n->{cn};
      $str->{login} = $n->{login};
      $str->{email} = $n->{email};
      $str->{device_name} = $n->{name};
      $str->{limit_in_mb} = _btomb($n->{limit_in});
      $str->{qs} = $n->{qs};
      $str->{notified} = $n->{notified};
    }
    $results->finish;
    1;
  };

  die "Database error: $@" unless defined $e;
  die "Device id is not found in database\n" unless $str;

  return $str;
}


# $mb = _btomb(1024)
sub _btomb {
  return sprintf('%.1f', shift() / 1048576);
}


1;
