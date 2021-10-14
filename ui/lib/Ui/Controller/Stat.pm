package Ui::Controller::Stat;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  my $login = $self->stash('remote_user') // '';
  $login = 'sorokinasv'; #FIXME
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

  $self->ua->get(Mojo::URL->new("/ui/search/1")->query(login => $login)->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      return $self->render(text => 'Ошибка соединения с управляющим сервером') unless defined $res;
      unless ($res->is_success) {
        if ($res->is_error) {
          if ($res->code == 404) {
            return $self->render(template => 'stat/nouser');
          } else {
            return $self->render(text => 'Ошибка запроса: '.$res->body);
          }
        }
        return $self->render(text => 'Неподдерживаемый ответ');
      }

      return unless my $v = $self->request_json($res);
      my $client_id = $v->{id};
      return unless $self->exists_and_number($client_id);

      $self->ua->get(Mojo::URL->new("/ui/stat/client/$client_id$q")->to_abs($self->head_url) =>
        {Accept => 'application/json'} =>
        sub {
          my ($ua, $tx1) = @_;
          my $res1 = eval { $tx1->result };
          return unless $self->request_success($res1);
          return unless my $v1 = $self->request_json($res1);

          return $self->render(
            client_id => $client_id,
            fullrec => $v1,
            rep => $reptype,
            activetab => $activetab
          );
        } # inner get closure
      );

    } # outer get closure
  );
}


sub emailpost {
  my $self = shift;
  return undef unless $self->authorize($self->allow_all_roles);

  my $login = $self->stash('remote_user') // '';

  my $id = $self->param('id');
  return unless $self->exists_and_number($id);

  my $reptype = $self->param('rep') // '';
  my $returl = $self->url_for('stat');
  $returl->query(rep => $reptype) if $reptype eq 'month';

  my $email_notify = $self->param('email_notify') ? 1 : 0;

  $self->render_later;

  # verify user
  $self->ua->get(Mojo::URL->new("/ui/search/1")->query(login => $login)->to_abs($self->head_url) =>
    {Accept => 'application/json'} =>
    sub {
      my ($ua, $tx) = @_;
      my $res = eval { $tx->result };
      unless ($res->is_success) {
        if ($res->is_error) {
          if ($res->code == 404) {
            $self->flash(oper => 'Сервис недоступен. Пользователь не найден.');
            return $self->redirect_to($returl);
          } else {
            return $self->render(text => 'Ошибка запроса: '.$res->body);
          }
        }
        return $self->render(text => 'Неподдерживаемый ответ');
      }

      return unless my $v = $self->request_json($res);
      if (defined $v->{id} && $v->{id} eq $id) {
        $self->ua->patch(Mojo::URL->new("/ui/client/1/$id")->to_abs($self->head_url)
          => json => { id => $id, email_notify => $email_notify} =>
          sub {
            my ($ua, $tx1) = @_;
            my $res1 = eval { $tx1->result };
            return unless $self->request_success($res1);

            # do redirect with flash
            $self->flash(oper => 'Уведомление по e-mail '.($email_notify ? 'включено.' : 'отключено.'));
            return $self->redirect_to($returl);
          } # inner patch closure
        );

      } else {
        $self->flash(oper => 'Сервис недоступен. Неверный пользователь.');
        return $self->redirect_to($returl);
      }
    } # outer get closure
  );

}


1;
