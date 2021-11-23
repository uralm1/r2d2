package Head::Ural::Profiles;
use Mojo::Base -base;

use Carp;
use Mojo::mysql;
use Mojo::Promise;
use Time::Piece;

# profiles hash structure:
# {
#   profile_key => {
#     name => 'Profile name',
#     lastcheck => 'чч:мм:сс дд-мм-гггг' or undef,
#     agents => {
#       agent_id => {
#         name => 'Agent name',
#         type => 'gwsyn',
#         url => 'https://1.2.3.4:2275',
#         block => 1 or 0,
#         state => 0/1/2, # 1-good, 0-bad, 2-unknown
#         status => 'test@host (3.00)',
#         lastcheck => 'чч:мм:сс дд-мм-гггг' or undef
#       },
#       ...
#     }
#   },
#   ...
# }

# new constructor
# my $obj = Head::Ural::Profiles->new();
# dies on errors
sub new {
  my ($class, $app, %opt) = @_;
  croak 'App parameter required!' unless $app;
  my $self = bless {
    app => $app,
    profiles => {},
  }, $class;
  #say 'Ural::Profiles constructor!';

  # load profiles configuration from config to database
  # to remove in future versions!
  $self->_compat_from_config_to_db unless $opt{dont_copy_config_to_db};

  unless (defined eval { $self->load }) {
    chomp $@;
    die "Profiles loading error: $@\n";
  }

  return $self;
}


# load all profiles from db syncronously
# $obj->load
sub load {
  my $self = shift;
  my $app = $self->{app};
  my $db = $app->mysql_inet->db;

  my $agent_types = $app->config('agent_types');

  my %_ren;
  my $results = eval { $db->query("SELECT id, profile, name, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck FROM profiles") };
  die "Profile select error\n" unless $results;
  my $p = $self->{profiles};
  while (my $next = $results->hash) {
    my $profile_key = $next->{profile};
    $p->{$profile_key} = {
      name => $next->{name} // 'Имя не задано',
      lastcheck => $next->{lastcheck}
    };
    $_ren{$next->{id}} = $profile_key;
  }
  # agents
  $results = eval { $db->query("SELECT id, profile_id, name, type, url, block, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck, state, status \
FROM profiles_agents") };
  die "Profile agents select error\n" unless $results;
  while (my $next = $results->hash) {
    my $type = $next->{type};
    die "Bad agent type!\n" unless grep($_ eq $type, @$agent_types);
    my $url = $next->{url};
    die "Bad agent url\n" unless defined $url and $url ne '';

    my $aa = {
      name => $next->{name} // 'Имя не задано',
      type => $type,
      url => $url,
      block => $next->{block} ? 1 : 0,
      lastcheck => $next->{lastcheck},
      state => $next->{state},
      status => $next->{status}
    };

    my $profile_key = $_ren{$next->{profile_id}};
    $p->{$profile_key}{agents}{$next->{id}} = $aa if defined $profile_key and exists $p->{$profile_key};
  }

  return 1;
}


# my $profiles = $obj->hash
sub hash {
  $_[0]->{profiles};
}


# $obj->each(sub { my ($profile_key, $profile) = @_; say "$profile_key => $profile->{name}" });
sub each {
  my ($self, $cb) = @_;
  while (my @e = CORE::each %{$self->{profiles}}) { $cb->(@e) }
  return $self;
}


# $obj->eachagent('this_profile_key', sub { my ($profile_key, $agent_key, $agent) = @_; say "$profile_key => $agent->{name}" });
# $obj->eachagent(sub { my ($profile_key, $agent_key, $agent) = @_; say "$profile_key => $agent->{name}" });
# returns 1 if ok, 0 - 'this_profile_key' is not found.
sub eachagent {
  my ($self, $pk, $cb) = @_;
  if (!defined $pk or ref $pk eq 'CODE') {
    $cb = $pk if defined $pk;
    while (my ($profile_key, $profile) = CORE::each %{$self->{profiles}}) {
      while (my @e = CORE::each %{$profile->{agents}}) {
        $cb->($profile_key, @e)
      }
    }
  } else {
    if (my $p = $self->{profiles}{$pk}) {
      while (my @e = CORE::each %{$p->{agents}}) {
        $cb->($pk, @e)
      }
    } else {
      return 0;
    }
  }
  return 1;
}


# update state, status, lastcheck from db
# my $all_db_promise = $obj->loadchecks_p
sub loadchecks_p {
  my $self = shift;
  my $db = $self->{app}->mysql_inet->db;

  my $profiles_p = $db->query_p("SELECT id, profile, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck FROM profiles");
  # agents
  my $agents_p = $db->query_p("SELECT id, profile_id, \
DATE_FORMAT(lastcheck, '%k:%i:%s %e-%m-%Y') AS lastcheck, state, status \
FROM profiles_agents");

  # return compound promise
  Mojo::Promise->all($profiles_p, $agents_p);
}


# '' = $obj->handle_loadchecks(@all_db_promise_resolve)
sub handle_loadchecks {
  my ($self, $profiles_p, $agents_p) = @_;

  my %_ren;
  my $p = $self->{profiles};
  while (my $next = $profiles_p->[0]->hash) {
    my $profile_key = $next->{profile};
    $p->{$profile_key}{lastcheck} = $next->{lastcheck};
    $_ren{$next->{id}} = $profile_key;
  }
  while (my $next = $agents_p->[0]->hash) {
    my $profile_key = $_ren{$next->{profile_id}};
    if (defined $profile_key and exists $p->{$profile_key}) {
      my $aref = $p->{$profile_key}{agents}{$next->{id}};
      $aref->{lastcheck} = $next->{lastcheck};
      $aref->{state} = $next->{state};
      $aref->{status} = $next->{status};
    }
  }
  return ''; # always success
}


# set state, status, update lastchecks
# ''|'error string' = $obj->setcheck($profile_key, $agent_key, $state, $status)
sub setcheck {
  my ($self, $profile_key, $agent_key, $state, $status) = @_;
  my $db = $self->{app}->mysql_inet->db;

  # database first
  my $results = eval { $db->query("UPDATE profiles_agents \
SET lastcheck = NOW(), state = ?, status = ? \
WHERE id = ?",
    $state,
    $status,
    $agent_key
  )};
  return 'Profile agent update error' unless $results;

  $results = eval { $db->query("UPDATE profiles \
SET lastcheck = NOW() \
WHERE profile = ?",
    $profile_key
  )};
  return 'Profile update error' unless $results;

  # and assign to memory hashes
  my $t = localtime;
  my $cur_t = $t->hms.' '.$t->dmy('-');

  my $p = $self->{profiles};
  if (exists $p->{$profile_key}) {
    my $profile = $p->{profile_key};

    if (exists $profile->{agents}{$agent_key}) {
      my $agent = $profile->{agents}{$agent_key};
      $agent->{state} = $state;
      $agent->{status} = $status;
      $agent->{lastcheck} = $cur_t;
    }
    $profile->{lastcheck} = $cur_t;
  }
  return '';
}


# deprecated
# upload configuration from config file to db,
# old db tables will be emptied!
# dies on error.
sub _compat_from_config_to_db {
  my $app = shift->{app};
  my $db = $app->mysql_inet->db;

  my $e = eval {
    $db->query('DELETE FROM profiles');
    $db->query('DELETE FROM profiles_agents');
  };
  die "Tables cleanup error\n" unless defined $e;

  my $profiles = $app->config('profiles_source');
  my $agent_types = $app->config('agent_types');

  while (my ($profile_key, $v) = CORE::each %$profiles) {
    my $results = eval { $db->query("INSERT INTO profiles (profile, name) \
VALUES (?, ?)",
      $profile_key,
      $v->{name} // 'Имя не задано'
    )};
    die "Profile insert error\n" unless $results;

    my $last_id = $results->last_insert_id;

    for my $agent (@{$v->{agents}}) {
      die "Agent url is not defined!\n" unless defined $agent->{url} && $agent->{url} ne '';
      my $a_t = $agent->{type};
      die "Agent type is invalid!\n" unless grep($_ eq $a_t, @$agent_types);

      $results = eval { $db->query("INSERT INTO profiles_agents \
(profile_id, name, type, url, block, state, status) \
VALUES (?, ?, ?, ?, ?, 2, 'Ожидание проверки...')",
        $last_id,
        $agent->{name} // 'Имя не задано',
        $a_t,
        $agent->{url},
        $agent->{block} ? 1 : 0
      )};
      die "Profile agent insert error\n" unless $results;
    } # agents loop

  } # profiles loop

  return 1;
}


# internal
sub _test_assign {
  my ($self, $profs) = @_;
  $self->{profiles} = $profs;
  return 1;
}


1;
