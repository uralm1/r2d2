package Head::Ural::NotifyClient;
use Mojo::Base -base;

use Mojo::File qw(path);
use Net::SMTP;
use Net::Domain qw(hostfqdn);
use Encode;
#use Carp;

use Exporter qw(import);
our @EXPORT_OK = qw(send_mail_notification);


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


1;
