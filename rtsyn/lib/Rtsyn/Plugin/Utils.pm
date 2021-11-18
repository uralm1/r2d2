package Rtsyn::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::URL;
use Mojo::UserAgent;
use Mojo::IOLoop;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};


  # remote logger
  $app->helper(rlog => sub {
    my ($self, $m, %param) = @_;
    croak 'Parameter missing' unless defined $m;

    my $sync = $param{sync} // 0;

    $self->log->info($m) if $self->config('rlog_local');

    if ($self->config('rlog_remote')) {
      my $url = Mojo::URL->new('/log/'.$self->stash('subsys'))->to_abs($self->head_url);
      if ($sync) {
        my $res = eval { $self->ua->post($url => $m)->result };
        unless (defined $res) {
          $self->log->error('Log request failed, probably connection refused');
        } else {
          $self->log->error('Log request error: '.substr($res->body, 0, 40)) if ($res->is_error);
        }

      } else {
        $self->ua->post($url => $m =>
          sub {
            my ($ua, $tx) = @_;
            my $res = eval { $tx->result };
            unless (defined $res) {
              $self->log->error('Log request failed, probably connection refused');
            } else {
              $self->log->error('Log request error: '.substr($res->body, 0, 40)) if ($res->is_error);
            }
          }
        );
        Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
      }
    }
  });


  # my $bool = $self->check_workers
  $app->helper(check_workers => sub {
    my $self = shift;
    my $stats = $self->ljq->stats;
    return ($stats->{active_workers} != 0 || $stats->{inactive_workers} != 0);
  });


  # my $bool = $self->is_myprofile($profile_to_check_or_undef)
  $app->helper(is_myprofile => sub {
    my ($self, $p) = @_;
    return undef unless $p;
    my $r = 0;
    for (@{ $self->config('my_profiles') }) {
      if ($p eq $_) { $r = 1; last }
    }
    return $r;
  });


  # my $mojo_url = $self->head_url();
  $app->helper(head_url => sub {
    state $head_url = Mojo::URL->new(shift->config('head_url'));
  });


  # my $ret = $app->system("command args")
  # my $ret = $app->system(iptables => "args")
  # my $ret = $app->system(iptables_restore => "args")
  # my [dump] = $app->system(iptables_dump => "args"), runs iptables actually, return undef on error
  $app->helper(system => sub {
    my ($self, @cmd) = @_;
    croak "Invalid argument" if @cmd < 1;

    my $w_opt = '';
    if (my $w = $self->config('iptables_wait')) {
      $w_opt = " --wait $w";
    }

    my $dumping;
    if ($cmd[0] eq 'iptables_dump') {
      shift @cmd;
      unshift @cmd, $self->config('iptables_path').$w_opt;
      $dumping = 1;

    } elsif ($cmd[0] eq 'iptables') {
      shift @cmd;
      unshift @cmd, $self->config('iptables_path').$w_opt;

    } elsif ($cmd[0] eq 'iptables_restore') {
      shift @cmd;
      unshift @cmd, $self->config('iptables_restore_path').$w_opt;
    }

    my $c = join ' ', @cmd;
    if ($self->config('iptables_simulation')) {
      $self->log->debug("SIMULATE: $c");
      return ($dumping ? [] : 0); # simulation is always success
    } else {
      # run
      if ($dumping) {
        my @r = `$c`;
        return (($?) ? undef : \@r);
      } else {
        return system $c;
      }
    }
  });
}

1;
__END__
