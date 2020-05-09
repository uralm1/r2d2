#!/usr/bin/perl -T
# This is the part of R2D2
# Active Directory ldap module
# author: Ural Khassanov, 2013
#

package R2ad;

use strict;
use warnings;
use Net::LDAP;

# configure credentials here
my @ldapservers = ('ldap://srv1', 'ldap://srv2');
my $ldapuser = 'ldapuser';
my $ldappass = 'ldappass';

#my $ldapbase = "OU=UWC Users,DC=uwc,DC=local";
my $ldapbase = "DC=uwc,DC=local";

#--------------------------------------------------
# my $entry = &R2ad::lookup_ad($login)
# returns Net::LDAP::Entry object or undef
sub lookup_ad {
  my $l = shift;

  my $ldap = Net::LDAP->new(\@ldapservers, port => 389, timeout => 3);
  if (!$ldap) {
    warn("Ldap connection error. Create object failed."); 
    return undef;
  }
 
  my $mesg = $ldap->bind($ldapuser, password => $ldappass, version => 3);
  if ($mesg->code) {
    warn("Ldap bind error: " . $mesg->error);
    return undef;
  }

  my $filter = "(&(objectClass=person)(sAMAccountName=$l))";
  my $res = $ldap->search(base => $ldapbase, filter => $filter,
    attrs => 'cn,sn,givenname,title,mail,physicaldeliveryofficename,telephonenumber,company');
  if ($res->code) {
    warn("Ldap search error: " . $res->error);
    $ldap->unbind;
    return undef;
  }

  my $count = $res->count;
  my $entry = undef;
  if ($count > 0) {
    $entry = $res->entry(0);
  }

  $ldap->unbind;
  return $entry;
}


#--------------------------------------------------

###
1;

