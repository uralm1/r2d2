package Ljq::Command::ljq;
use Mojo::Base 'Mojolicious::Commands';

has description => 'Lightweight job queue';
has hint        => <<EOF;

See 'APPLICATION ljq help COMMAND' for more information on a specific
command.
EOF
has message    => sub { shift->extract_usage . "\nCommands:\n" };
has namespaces => sub { ['Ljq::Command::ljq'] };

sub help { shift->run(@_) }

1;

=encoding utf8

=head1 NAME

Ljq::Command::ljq - Ljq command

=head1 SYNOPSIS

  Usage: APPLICATION ljq COMMAND [OPTIONS]

=head1 DESCRIPTION

L<Ljq::Command::ljq> lists available L<Ljq> commands.

=head1 ATTRIBUTES

L<Ljq::Command::ljq> inherits all attributes from L<Mojolicious::Commands> and implements the following new ones.

=head2 description

  my $description = $ljq->description;
  $ljq            = $ljq->description('Foo');

Short description of this command, used for the command list.

=head2 hint

  my $hint = $ljq->hint;
  $ljq     = $ljq->hint('Foo');

Short hint shown after listing available L<Ljq> commands.

=head2 message

  my $msg = $ljq->message;
  $ljq    = $ljq->message('Bar');

Short usage message shown before listing available L<Ljq> commands.

=head2 namespaces

  my $namespaces = $ljq->namespaces;
  $ljq           = $ljq->namespaces(['MyApp::Command::ljq']);

Namespaces to search for available L<Ljq> commands, defaults to L<Ljq::Command::ljq>.

=head1 METHODS

L<Ljq::Command::ljq> inherits all methods from L<Mojolicious::Commands> and implements the following new ones.

=head2 help

  $ljq->help('app');

Print usage information for L<Ljq> command.

=head1 SEE ALSO

L<Minion>, L<Minion::Guide>, L<https://minion.pm>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
