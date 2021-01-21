package Rtsyn::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::UserAgent;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # remote logger
  $app->helper(rlog => sub {
    my ($self, $m) = @_;

    $self->log->info($m) if $self->config('rlog_local');

    if ($self->config('rlog_remote')) {
      my $url = $self->config('head_url').'/log/'.$self->stash('subsys');
      $self->ua->post($url => $m =>
        sub {
          my ($ua, $tx) = @_;
          my $e = eval {
            my $res = $tx->result;
            $self->log->error('Log request error: '.$res->body) if ($res->is_error);
          };
          $self->log->error('Log request failed, probably connection refused') unless defined $e;
        }
      );
      Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
    }
  });


  # my $bool = $self->check_workers
  $app->helper(check_workers => sub {
    my $self = shift;
    my $stats = $self->minion->stats;
    return ($stats->{active_workers} != 0 || $stats->{inactive_workers} != 0);
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
