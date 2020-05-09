# ./perl

use warnings;
use Log::Fast;

open(LOGFILE, '>>', 'b.log');

$log = Log::Fast->new({
  level => 'DEBUG',
  prefix => '%D %T ',
  type => 'fh',
  fh => \*LOGFILE,
});

#$log->ident('anotherapp');
#$log->level('INFO');

$log->ERR('Some error');
$log->WARN('Some warning');
$log->NOTICE('user %s logged in', 'test');
$log->INFO('data loaded');
$log->DEBUG('user have things');

close LOGFILE;