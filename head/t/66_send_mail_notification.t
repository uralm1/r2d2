use Mojo::Base -strict;

use Test::Mojo;
use Test::More;
use Head::Ural::NotifyClient qw(send_mail_notification);
use Net::Domain qw(hostdomain);

plan skip_all => 'Set SMTP_HOST, MAIL_TO variables to enable online test' unless $ENV{SMTP_HOST} and $ENV{MAIL_TO};

#
# Add sender host to DKIM settings to not check authentication results
#

my $t = Test::Mojo->new('Head', {
  smtp_host => $ENV{SMTP_HOST},
  mail_from => 'r2d2@'.hostdomain(),
  mail_templates => {
    1 => 'mail1.txt',
    2 => 'mail2.txt',
    3 => 'mail3.txt',
  },
});

my $r = eval { send_mail_notification($t->app, $ENV{MAIL_TO}, 'Тест Test', 1, 1122) };
diag "Send mail error: $@" unless ($r);
ok($r, 'send_mail_notification');

done_testing();
