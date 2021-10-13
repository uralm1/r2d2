package Ui::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  say "USER:".$self->stash('remote_user');

  my $client_id = 1; #TODO
  my $reptype = $self->param('rep') // '';

  my $activetab;
  my $q = '';
  if ($reptype eq 'month') {
    $activetab = 2;
    $q = '?rep=month';
  } else {
    $activetab = 1;
  }

  $self->render_later;

  $self->ua->get(Mojo::URL->new("/ui/stat/client/$client_id$q")->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return unless $self->request_success($res);
      return unless my $v = $self->request_json($res);

      return $self->render(
        client_id => $client_id,
        fullrec => $v,
        rep => $reptype,
        activetab => $activetab
      );
    } # get closure
  );
}


1;
