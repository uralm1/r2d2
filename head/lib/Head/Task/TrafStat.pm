package Head::Task::TrafStat;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::mysql;

sub register {
  my ($self, $app) = @_;
  $app->minion->add_task(traf_stat => sub {
    my ($job, $timestamp, $profs, $j) = @_;
    die 'Bad job parameters' unless defined $timestamp && $profs && $j;
    my $app = $job->app;

    my $m = 'Traffic statistics processing /experimental/ job at '.localtime $timestamp;
    $app->dblog->info($m, sync=>1);

    $job->finish;
  });
}


1;
