package Ui::Plugin::Utils;
use Mojo::Base 'Mojolicious::Plugin';

use Ui::Ural::LogColorer;
use Ui::Ural::OperatorResolver;
use Mojo::URL;

sub register {
  my ($self, $app, $args) = @_;
  $args ||= {};

  # my $mojo_url = $self->head_url;
  $app->helper(head_url => sub {
    state $head_url = Mojo::URL->new(shift->config('head_url'));
  });


  # $role_or_undef = get_user_role('mylogin');
  $app->helper(get_user_role => sub {
    my ($self, $login) = @_;
    return undef if $login eq 'default';

    my $users = $self->config('users');
    return $users->{$login} if defined $users->{$login};
    return $users->{'default'} if defined $users->{'default'};
    return undef;
  });


  # return undef unless $self->authorize({ admin=>1 });
  $app->helper(authorize => sub {
    my ($c, $roles_href) = @_;

    my $role = $c->stash('remote_user_role');
    return 1 if ($role && $roles_href->{$role});
    $c->app->log->warn("Access is forbidden for role: $role, user: ".$c->stash('remote_user'));
    $c->render(text => 'Доступ запрещён. Обратитесь в группу сетевого администрирования.', status => 401);
    return undef;
  });

  # $self->authorize($self->allow_all_roles);
  $app->helper(allow_all_roles => sub {
    { admin=>1, client=>1 };
  });


  # log_rowcolor singleton
  $app->helper(log_rowcolor => sub {
    shift;
    state $log_colorer = Ui::Ural::LogColorer->new;
    return $log_colorer->color(shift);
  });


  # $self->exists_and_number($value)
  # renders error if not number
  $app->helper(exists_and_number => sub {
    my ($self, $v) = @_;
    unless (defined $v && $v =~ /^\d+$/) {
      $self->render(text => 'Ошибка данных');
      return undef;
    }
    return 1;
  });


  # my $full_operator_name = oprs($login)
  $app->helper(oprs => sub {
    my ($self, $login) = @_;
    # oprs object singleton
    state $oprs = Ui::Ural::OperatorResolver->new($self->config);
    return $oprs->resolve($login);
  });

}

1;
