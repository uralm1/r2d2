package Head::Ural::NotifyClient;
use Mojo::Base -base;

use Mojo::mysql;
use Mojo::Loader qw(data_section load_class);
use Net::SMTP;
use Net::Domain qw(hostfqdn);
use Net::LDAP qw(LDAP_SUCCESS LDAP_NO_SUCH_OBJECT);
use Net::LDAP::Util qw(escape_filter_value);
use Encode;
#use Carp;
#use Data::Dumper;

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail_notification retrive_login_db_attr retrive_ad_fullname_email);


# send_mail_notification($app, $user_email, $user_fullname, $user_qs, $user_limit_mb)
# die with error message on errors
sub send_mail_notification {
  my ($app, $to, $fullname, $qs, $limit_mb) = @_;
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
    USERNAME => $fullname,
    USEREMAIL => $to,
    USERLIMIT => $limit_mb,
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


# $str = retrive_login_db_attr($app, $id)
# $str = { login => 'login', limit_in_mb => 12345, qs => 1, notified => 0 }
# die with error message on errors
sub retrive_login_db_attr {
  my ($app, $id) = @_;

  my $str = undef;
  my $e = eval {
    my $results = $app->mysql_inet->db->query("SELECT login, limit_in, qs, notified FROM devices WHERE id = ?", $id);
    if (my $n = $results->hash) {
      $str->{login} = $n->{login};
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


# $str = retrive_ad_fullname_email($app, $login)
# $str = { fullname => 'F I O', email => 'user@testdomain' }
# die with error message on errors
sub retrive_ad_fullname_email {
  my ($app, $login) = @_;

  my $ldap = Net::LDAP->new($app->config('ldap_servers'), port => 389, timeout => 5, version => 3);
  unless ($ldap) {
    die "LDAP connection error. Create object failed.\n";
  }

  my $mesg = $ldap->bind($app->config('ldap_user'), password => $app->config('ldap_pass'));
  if ($mesg->code) {
    die "LDAP bind error: ".$mesg->error."\n";
  }

  my $flogin = escape_filter_value $login;
  my $filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$flogin))";
  $mesg = $ldap->search(base => $app->config('ldap_base'), scope => 'sub',
    filter => $filter,
    attrs => ['cn', 'sn', 'givenname', 'mail']
  );
  if ($mesg->code && $mesg->code != LDAP_NO_SUCH_OBJECT) {
    die "LDAP search error: ".$mesg->error."\n";
  }

  my $str;
  if ($mesg->count > 0) {
    my $entry = $mesg->entry(0);
    my @ll;
    for (qw/sn givenname cn/) {
      my $v = decode_utf8($entry->get_value($_) // '');
      $v = "($v)" if $v and /^cn$/;
      push @ll, $v if $v;
    }
    $str = {
      fullname => join(' ', @ll),
      email => $entry->get_value('mail'),
    }
  } else {
    $ldap->unbind;
    die "No data from active directory\n";
  }

  $ldap->unbind;
  return $str;
}


# $mb = _btomb(1024)
sub _btomb {
  return sprintf('%.1f', shift() / 1048576);
}


1;
