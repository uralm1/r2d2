#!/usr/bin/perl -T
# This is the part of R2D2
# Database module
# author: Ural Khassanov, 2013
#

package R2db;

use strict;
use warnings;
use DBI;

# configure credentials here
my $dbhost = 'localhost';
my $dbdb = 'inet';
my $dbuser = 'user';
my $dbpass = 'pass';

my $dbh_inet;

#--------------------------------------------------
sub open_dbs {
  if (!($dbh_inet = DBI->connect("DBI:mysql:database=$dbdb;host=$dbhost", $dbuser, $dbpass))) {
    die "Connection to database $dbdb failed!\n";
  }
  $dbh_inet->do("SET NAMES 'UTF8'");
}

sub close_dbs {
  $dbh_inet->disconnect;
}

#--------------------------------------------------
sub dbh_inet {
  return $dbh_inet;
}

# &R2db::dblog("msg");
sub dblog {
  my $q_msg = $dbh_inet->quote(&R2utils::remote_user.': '.shift);
  $dbh_inet->do("REPLACE INTO log_admin \
SET row_id = (SELECT COALESCE(MAX(log_id), 0) % 5000 + 1 \
FROM log_admin AS t), \
msg = $q_msg");
}

###
1;

