#!/usr/bin/perl
use Mojo::Base -strict;
use Mojo::URL;

my $head_url = Mojo::URL->new('https://10.14.72.5:2271');
say $head_url;

my $url = Mojo::URL->new('/clients/asdf')->to_abs($head_url)->query(profile => ['plk', 'gwtest1']);
say $url;
