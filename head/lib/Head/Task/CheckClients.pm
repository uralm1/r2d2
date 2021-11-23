package Head::Task::CheckClients;
use Mojo::Base 'Mojolicious::Plugin';

#use Carp;
use Mojo::mysql;
use Net::LDAP qw(LDAP_SUCCESS LDAP_INSUFFICIENT_ACCESS LDAP_NO_SUCH_OBJECT LDAP_SIZELIMIT_EXCEEDED);
use Net::LDAP::Util qw(escape_filter_value);
use Encode qw(decode_utf8);

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(check_clients => sub {
    my $job = shift;
    my $app = $job->app;

    $app->log->info('Check clients operation started');

    unless (defined eval { _do($app) }) {
      chomp $@;
      $app->log->error("Fatal error. $@");
    } else {
      ###
      $app->dblog->info('Check clients operation performed.', sync=>1);
    }

    $app->log->info('Check clients operation finished');
    $job->finish;
  });
}


# _do($app)
# dies on error
sub _do {
  my $app = shift;

  my $db = $app->mysql_inet->db;
  my $results = $db->query("SELECT id, guid, login, cn, email, lost \
FROM clients c WHERE type = 0 AND guid IS NOT NULL AND guid != ''");

  my $ldap = Net::LDAP->new($app->config('ldap_servers'), port => 389, timeout => 10, version => 3);
  die "LDAP object creation error\n" unless $ldap;

  my $mesg = $ldap->bind($app->config('ldap_user'), password => $app->config('ldap_pass'));
  die 'LDAP bind error: '.$mesg->error."\n" if $mesg->code;

  while (my $n = $results->hash) {
    #say "Client $n->{id}, $n->{cn} ($n->{login}, $n->{email})";
    my $safe_guid = escape_filter_value($n->{guid}); # security filtering
    my $filter = "(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))";
    $mesg = $ldap->search(base => "<GUID=$safe_guid>", scope => 'base',
      filter => $filter,
      attrs => ['displayName', 'sAMAccountName', 'userAccountControl', 'title', 'mail']
    );
    if ($mesg->code && $mesg->code != LDAP_NO_SUCH_OBJECT) {
      $app->log->error('LDAP search error: '.$mesg->error);
      next;
    }

    #my $count = $mesg->count; say "found: $count";
    if ($mesg->count > 0) {
      my $entry = $mesg->entry(0);

      my $ad_rec = {};
      $ad_rec->{cn} = decode_utf8($entry->get_value('displayName'));
      $ad_rec->{login} = lc decode_utf8($entry->get_value('sAMAccountName'));
      $ad_rec->{email} = decode_utf8($entry->get_value('mail')) // '';
      $n->{email} //= '';
      #say "found: $ad_rec->{cn} ($ad_rec->{login}, $ad_rec->{email})!";
      my @set_expr;
      for (qw/cn login email/) {
        push @set_expr, "$_ = ".$db->quote($ad_rec->{$_}) if $n->{$_} ne $ad_rec->{$_};
      }
      push @set_expr, 'lost = 0' if $n->{lost} ne '0';
      if (@set_expr) {
        # save differences to database
        $app->log->info("Client $n->{cn} ($n->{login}) fixing differences");
        #say 'UPDATE clients SET '.join(', ', @set_expr).' WHERE id = ?';
        my $results1 = eval {
          $db->query('UPDATE clients SET '.join(', ', @set_expr).' WHERE id = ?', $n->{id})
        };
        unless ($results1) {
          $app->log->error('Client update database error');
          next;
        }
      } else {
        #say 'No difference!';
      }

    } else {
      # not found (set lost)
      #say "Not found!";
      if ($n->{lost} ne '1') {
        $app->log->info("Client $n->{cn} ($n->{login}) set to lost");
        my $results1 = eval { $db->query('UPDATE clients SET lost = 1 WHERE id = ?', $n->{id}) };
        unless ($results1) {
          $app->log->error('Client update database set lost error');
          next;
        }
      }
    }
  } # clients loop

  $ldap->unbind;

  return 1;
}


1;
