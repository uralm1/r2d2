package Head::Ural::NotifyClient;
use Mojo::Base -base;

use Mojo::File qw(path);
use Mojo::mysql;
use Net::SMTP;
use Net::Domain qw(hostfqdn);
use Net::LDAP qw(LDAP_SUCCESS LDAP_NO_SUCH_OBJECT);
use Net::LDAP::Util qw(escape_filter_value);
use Encode;
use Carp;

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail_notification retrive_login_limit retrive_ad_fullname_email);


# send_mail_notification($app, $user_email, $user_fullname, $user_qs, $user_limit_mb)
sub send_mail_notification {
  my ($app, $to, $fullname, $qs, $limit_mb) = @_;
  $limit_mb //= '---';

  my $_file = $app->config('mail_templates')->{$qs} or
    die 'Mail template error. Unsupported quota mode.';
  # read and fill mail template
  my $templ = path($_file);
  my $fh = eval { $templ->open('<:encoding(UTF-8)'); } or
    die "Mail error. Can't open mail template file: $!";

  my @content;
  while (<$fh>) {
    #$_ = decode_utf8($_);
    my $s = '';
    while (/%%([A-Za-z0-9_-]+)%%/) {
      $s = $`;
      if ($1 eq 'USERNAME') {
        $s .= $fullname;
      } elsif ($1 eq 'USEREMAIL') {
        $s .= $to;
      } elsif ($1 eq 'USERLIMIT') {
        $s .= $limit_mb;
      } else {
        $s .= $&;
        warn "Mail warning. Unknown template $& in template file.";
      }
      $_ = $';
    }
    push @content, encode_utf8($s . $_);
  }

  $fh->close or die "Mail error. Can't close mail template file: $!";

  # send mail
  my $smtp = Net::SMTP->new($app->config('smtp_host'), Hello => hostfqdn() // 'r2d2.domainname', Timeout => 10, Debug => 0) or
    die 'Mail error. Create smtp object failed.';

  unless ($smtp->mail($app->config('mail_from'))) {
    $smtp->quit;
    die 'Mail error. Mail command failed.';
  }
  unless ($smtp->to($to)) {
    $smtp->quit;
    die 'Mail error. Rcpt command failed.';
  }
  unless ($smtp->data(@content)) {
    $smtp->quit;
    die 'Mail error. Data command failed.';
  }
  $smtp->quit;
  return 1;
}


# $str = retrive_login_limit($app, $id)
# $str = { login => 'login', limit_in_mb => 12345 }
# die with error message on errors
sub retrive_login_limit {
  my ($app, $id) = @_;

  my $str = undef;
  my $e = eval {
    my $results = $app->mysql_inet->db->query("SELECT login, limit_in FROM clients WHERE id = ?", $id);
    if (my $n = $results->hash) {
      $str->{login} = $n->{login};
      $str->{limit_in_mb} = _btomb($n->{limit_in});
    }
    $results->finish;
    1;
  };

  die "Database error: $@" unless defined $e;
  croak "User is not found" unless $str;

  return $str;
}


# $str = retrive_ad_fullname_email($app, $login)
# $str = { fullname => 'F I O', email => 'user@testdomain' }
# die with error message on errors
sub retrive_ad_fullname_email {
  my ($app, $login) = @_;

  my $ldap = Net::LDAP->new($app->config('ldap_servers'), port => 389, timeout => 5, version => 3);
  unless ($ldap) {
    die "LDAP connection error. Create object failed.";
  }

  my $mesg = $ldap->bind($app->config('ldap_user'), password => $app->config('ldap_pass'));
  if ($mesg->code) {
    die "LDAP bind error: ".$mesg->error;
  }

  my $flogin = escape_filter_value $login;
  my $filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$flogin))";
  $mesg = $ldap->search(base => $app->config('ldap_base'), scope => 'sub',
    filter => $filter,
    attrs => ['cn', 'sn', 'givenname', 'mail']
  );
  if ($mesg->code && $mesg->code != LDAP_NO_SUCH_OBJECT) {
    die "LDAP search error: ".$mesg->error;
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
    croak "No data from active directory";
  }

  $ldap->unbind;
  return $str;
}


# $mb = _btomb(1024)
sub _btomb {
  return sprintf('%.1f', shift() / 1048576);
}


1;
