package Head::Controller::UiList;
use Mojo::Base 'Mojolicious::Controller';

use POSIX qw(ceil);
use Mojo::mysql;
use Mojo::Promise;
use Regexp::Common qw(net);

sub list {
  my $self = shift;
  my $page = $self->param('page') // 1; # page is always defined
  my $lines_on_page = $self->param('lop');
  my $lostonlyifexist = $self->param('lostonlyifexist');
  return $self->render(text => 'Bad parameter format', status => 400) unless defined $lines_on_page &&
    $lines_on_page =~ /^\d+$/ && $page =~ /^\d+$/ && $lines_on_page > 0 &&
    (!defined $lostonlyifexist || (defined $lostonlyifexist && $lostonlyifexist =~ /^[0,1]$/));
  return $self->render(text => 'Max 100 per page', status => 400) if $lines_on_page > 100;
  $self->stash(page => $page, lines_on_page => $lines_on_page);
  $self->stash(lostonlyifexist => $lostonlyifexist);

  my $search = $self->param('s');
  my $view = $self->param('v') // '';
  return $self->render(text => 'Invalid view option', status => 400)
    unless $view =~ /^(?:|clients|lost|pain|servers|devices|flagged)$/;
  my $sort = $self->param('sort') // '';
  return $self->render(text => 'Invalid sort option', status => 400)
    unless $sort =~ /^(?:|cn|login|ip|place|rt)$/;

  my $_view_mode_clients = $view =~ /^(?:|clients|lost|pain|servers)$/;
  my $_view_mode_devices = $view =~ /^(?:devices|flagged)$/;
  my $view_mode;


  $self->render_later;

  my $db = $self->mysql_inet->db; # we'll use same connection

  $self->stash(j => []); # resulting d attribute

  $self->count_warn_p($db)
  ->then(sub {
    my $err = $self->handle_count_warn(@_);
    if ($err) {
      Mojo::Promise->reject($err);
    } else {
      if ($_view_mode_clients) {
        $view_mode = 'clients';
        $self->count_clients_p($db);
      } elsif ($_view_mode_devices) {
        $view_mode = 'devices';
        $self->count_devices_p($db);
      } else {
        die;
      }
    }

  })->then(sub {
    if ($_view_mode_clients) {
      my $err = $self->handle_count_clients(@_);
      if ($err) {
        Mojo::Promise->reject($err);
      } else {
        $self->clients_p($db, $lostonlyifexist && $self->stash('has_lost_clients'));
      }
    } elsif ($_view_mode_devices) {
      my $err = $self->handle_count_devices(@_);
      if ($err) {
        Mojo::Promise->reject($err);
      } else {
        $self->devices_p($db);
      }
    }

  })->then(sub {
    if ($_view_mode_clients) {
      my $err = $self->handle_clients(@_);
      if ($err) {
        Mojo::Promise->reject($err);
      } else {
        $self->client_devices_p($db);
      }
    } elsif ($_view_mode_devices) {
      my $err = $self->handle_devices(@_);
      Mojo::Promise->reject($err) if $err;
    }

  })->then(sub {
    if ($_view_mode_clients) {
      my $err = $self->handle_client_devices(@_);
      Mojo::Promise->reject($err) if $err;
    }

  })->then(sub {
    my $j = $self->stash('j');
    #say $self->dumper($j);

    $self->render(json => {
      d => $j,
      lines_total => $self->stash('lines_total'),
      lines_total_all => $self->stash('lines_total_all'),
      pages => $self->stash('num_pages'),
      page => $page,
      lines_on_page => $lines_on_page,
      view_mode => $view_mode,
      has_pain_clients => $self->stash('has_pain_clients'),
      has_lost_clients => $self->stash('has_lost_clients')
    });

  })->catch(sub {
    my $err = shift;
    if ($err =~ /^bad parameter value/i) {
      $self->render(text => $err, status => 400);
    } elsif ($err =~ /^client attribute error/i || $err =~ /^device attribute error/i) {
      $self->render(text => $err, status => 503);
    } else {
      $self->log->error($err);
      $self->render(text => "Database error: $err", status => 503);
    }
  });
}


# $all_db_promise = $self->count_warn_p($db)
sub count_warn_p {
  my ($self, $db) = @_;

  my $count_lost_p = $db->query_p("SELECT COUNT(*) FROM clients WHERE type = 0 AND lost = 1");
  my $count_pain_p = $db->query_p("SELECT COUNT(*) FROM clients WHERE type = 0 AND guid = ''");

  # return compound promise
  Mojo::Promise->all($count_lost_p, $count_pain_p);
}


# ''|'error string' = $self->handle_count_warn($all_db_promise_resolve)
sub handle_count_warn {
  my ($self, $count_lost_p, $count_pain_p) = @_;

  my $lines_lost = $count_lost_p->[0]->array->[0];
  my $lines_pain = $count_pain_p->[0]->array->[0];
  $self->stash(lines_lost => $lines_lost);
  $self->stash(has_pain_clients => $lines_pain > 0 ? 1 : 0);
  $self->stash(has_lost_clients => $lines_lost > 0 ? 1 : 0);

  # success
  return '';
}


# $db_promise = $self->count_clients_p($db)
sub count_clients_p {
  my ($self, $db) = @_;
  $db->query_p("SELECT COUNT(*) FROM clients");
}


# ''|'error string' = $self->handle_count_clients($db_promise_resolve)
sub handle_count_clients {
  my ($self, $results) = @_;

  my $lines_lost = $self->stash('lines_lost');
  my $lines_total_all = $results->array->[0];

  my $lines_total;
  if ($lines_lost > 0 && $self->stash('lostonlyifexist')) {
    $lines_total = $lines_lost;
  } else {
    $lines_total = $lines_total_all;
  }

  my $page = $self->stash('page');
  my $lines_on_page = $self->stash('lines_on_page');

  my $num_pages = ceil($lines_total / $lines_on_page);
  return 'Bad parameter value' if $page < 1 || ($num_pages > 0 && $page > $num_pages);

  $self->stash(lines_total_all => $lines_total_all, lines_total => $lines_total, num_pages => $num_pages);

  # success
  return '';
}


# $db_promise = $self->count_devices_p($db)
sub count_devices_p {
  my ($self, $db) = @_;
  $db->query_p("SELECT COUNT(*) FROM devices d INNER JOIN clients c ON d.client_id = c.id");
}


# ''|'error string' = $self->handle_count_devices($db_promise_resolve)
sub handle_count_devices {
  my ($self, $results) = @_;

  my $lines_total_all = $results->array->[0];
  my $lines_total = $lines_total_all;

  my $page = $self->stash('page');
  my $lines_on_page = $self->stash('lines_on_page');

  my $num_pages = ceil($lines_total / $lines_on_page);
  return 'Bad parameter value' if $page < 1 || ($num_pages > 0 && $page > $num_pages);

  $self->stash(lines_total_all => $lines_total_all, lines_total => $lines_total, num_pages => $num_pages);

  # success
  return '';
}


# $db_promise = $self->clients_p($db, $onlylost)
sub clients_p {
  my ($self, $db, $onlylost) = @_;
  my $lines_on_page = $self->stash('lines_on_page');

  my $where = $onlylost ? ' WHERE lost = 1' : '';
  $db->query_p("SELECT id, type, guid, login, c.desc, DATE_FORMAT(create_time, '%k:%i:%s %e-%m-%y') AS create_time, cn, email, email_notify, lost \
FROM clients c$where \
ORDER BY id ASC LIMIT ? OFFSET ?",
    $lines_on_page,
    ($self->stash('page') - 1) * $lines_on_page
  );
}


# ''|'error string' = $self->handle_clients($db_promise_resolve)
sub handle_clients {
  my ($self, $results) = @_;

  my $j = $self->stash('j');

  while (my $next = $results->hash) {
    my $cl = eval { Head::Controller::UiClients::_build_client_rec($next) };
    return 'Client attribute error' unless $cl;

    push @$j, $cl;
  }
  # success
  return '';
}


# $all_db_promise = $self->client_devices_p($db)
sub client_devices_p {
  my ($self, $db) = @_;
  my $j = $self->stash('j');

  if (@$j) {
    # return map promise with limited concurrency
    Mojo::Promise->map(
      {concurrency => 1},
      sub {
        $db->query_p("SELECT d.id, d.name, d.desc, DATE_FORMAT(create_time, '%k:%i:%s %e-%m-%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, d.profile, p.name AS profile_name, d.client_id AS client_id \
FROM devices d LEFT OUTER JOIN profiles p ON d.profile = p.profile WHERE d.client_id = ? \
ORDER BY d.id ASC LIMIT 20", $_->{id})
      },
      @$j
    );
  } else {
    Mojo::Promise->resolve();
  }
}


# ''|'error string' = $self->handle_client_devices(@db_map_promise_resolve)
sub handle_client_devices {
  my $self = shift;
  my $j = $self->stash('j');

  my $i = 0;
  for my $dev_p (@_) {
    my $devs = undef;
    if (my $d = $dev_p->[0]->hashes) {
      $devs = $d->map(sub { return eval { Head::Controller::UiDevices::_build_device_rec($_) } })->compact;
    } else {
      return 'bad result'; # will output 'Database error: bad result', status => 503
    }
    $j->[$i]{devices} = $devs;;
    $i++;
  }
  # success
  return '';
}


# $db_promise = $self->devices_p($db)
sub devices_p {
  my ($self, $db) = @_;
  my $lines_on_page = $self->stash('lines_on_page');

  $db->query_p("SELECT d.id, d.name, d.desc, DATE_FORMAT(d.create_time, '%k:%i:%s %e-%m-%y') AS create_time, \
ip, mac, rt, no_dhcp, defjump, speed_in, speed_out, qs, limit_in, blocked, d.profile, p.name AS profile_name, d.client_id AS client_id, c.cn AS client_cn, c.login AS client_login \
FROM devices d INNER JOIN clients c ON d.client_id = c.id LEFT OUTER JOIN profiles p ON d.profile = p.profile \
ORDER BY d.id ASC LIMIT ? OFFSET ?",
    $lines_on_page,
    ($self->stash('page') - 1) * $lines_on_page
  );
}


# ''|'error string' = $self->handle_devices($db_promise_resolve)
sub handle_devices {
  my ($self, $results) = @_;
  my $j = $self->stash('j');

  while (my $next = $results->hash) {
    my $d = eval { Head::Controller::UiDevices::_build_device_rec($next) };
    return 'Device attribute error' unless $d;

    push @$j, $d;
  }
  # success
  return '';
}


# internal
sub _isip {
  my $s = shift;
  defined $s && ($s =~ /^$RE{net}{IPv4}$/ || $s =~ /^$RE{net}{MAC}$/);
}

# internal
sub _istext {
  my $s = shift;
  defined $s && $s ne '';
}


1;
