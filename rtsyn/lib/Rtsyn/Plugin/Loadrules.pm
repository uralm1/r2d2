package Rtsyn::Plugin::Loadrules;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::File qw(tempfile);
use Mojo::UserAgent;

use Carp;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # build rulefile and load it to iptables (blocking)
  # doesn't log anything to remote log, returns 1-success, 0-error
  $app->helper(load_rules => sub {
    my $self = shift;
    my $ftitle = 'load_rules: ';

    my $res;
    my $e = eval {
      my $tx = $self->ua->get($self->config('head_url').'/clients' => {Accept => 'application/json'});
      $res = $tx->result;
    };
    if (defined $e) {
      if ($res->is_success) {
        my $v = $res->json;
        if ($v) {
          # create rule-file
	  my $rulefile = tempfile;
          my $fh = $rulefile->open('>');
	  if (defined $fh) {

	    my $client_out_chain = $self->config('client_out_chain');

	    # header
            print $fh "# WARNING: this is autogenerated file, don't run or change it!\n\n";
            print $fh "*mangle\n";
            print $fh ":$client_out_chain - [0:0]\n\n";

	    # data
	    for (@$v) {
	      #print $fh "# $_->{id}: $_->{login}\n";
              print $fh "-A $client_out_chain -s $_->{ip} -m comment --comment $_->{id} ".$self->rt_marks($_->{rt})."\n";
	    }

	    # footer
            print $fh "COMMIT\n";
	    $fh->close;
	    
	    # load rules with iptables_restore
	    # note: iptables_restore still flushes user chains mentioned in file
	    if (!$self->system(iptables_restore => "--noflush < $rulefile")) {
	      return 1; # success
	    } else {
              $self->log->error("${ftitle}Can't activate rules configuration");
	    }

	  } else {
            $self->log->error("${ftitle}Can't create temporary file: $!");
	  }
	} else {
          $self->log->error("${ftitle}Clients response json error");
	}
      } else {
        $self->log->error("${ftitle}Clients request error: ".$res->body) if $res->is_error;
      }
    } else {
      $self->log->error("${ftitle}Connection to head failed: $@");
    }
    return 0; #error
  });
}

1;
__END__