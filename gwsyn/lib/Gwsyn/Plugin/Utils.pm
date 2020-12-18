package Gwsyn::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(path);
use Mojo::UserAgent;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # remote logger
  $app->helper(rlog => sub {
    my ($self, $m) = @_;
    $self->log->info($m);

    my $url = $self->config('head_url').'/log/'.$self->stash('subsys');
    $self->ua->post($url => $m =>
      sub {
        my ($ua, $tx) = @_;
        my $e = eval {
          my $res = $tx->result;
          $self->log->error('Log request error: '.$res->body) if ($res->is_error);
        };
        $self->log->error("Log request failed: $@") unless defined $e;
      }
    );
  });


  # my $ret = $app->system("command args")
  # my $ret = $app->system(iptables => "args")
  # my $ret = $app->system(iptables_restore => "args")
  $app->helper(system => sub {
    my ($self, @cmd) = @_;
    croak "Invalid argument" if @cmd < 1;

    my $w_opt = '';
    if (my $w = $self->config('iptables_wait')) {
      $w_opt = " --wait $w";
    }

    if ($cmd[0] eq 'iptables') {
      shift @cmd;
      unshift @cmd, $self->config('iptables_path').$w_opt;

    } elsif ($cmd[0] eq 'iptables_restore') {
      shift @cmd;
      unshift @cmd, $self->config('iptables_restore_path').$w_opt;
    }

    my $c = join ' ', @cmd;
    if ($self->config('iptables_simulation')) {
      $self->log->debug("SIMULATE: $c");
      return 0; # simulation is always success
    } else {
      # run
      return system $c;
    }
  });


  # my $err = $app->sighup_dnsmasq()
  # returns 1-success, dies on error
  $app->helper(sighup_dnsmasq => sub {
    my $self = shift;
    my $pidfile;
    my $pid_re = $self->config('dnsmasq_pidfile_regexp');
    for (@{path($self->config('dnsmasq_pid_dir'))->list}) {
      if (/$pid_re/) {
         $pidfile = $_;
         last;
       }
    }
    croak 'dnsmasq pidfile is not found!' unless $pidfile;
    chomp(my $pid = $pidfile->slurp);
    croak 'dnsmasq pid is invalid!' unless $pid =~ /^\d+$/;

    #say "Dnsmasq PID: ".$pid;
    croak "can not send hup signal to pid $pid!" unless kill('HUP', $pid) != 1;
    return 1;
  });
}

1;
__END__
