#!/usr/bin/perl -wT

#warn "fuck fuck\n";
print "Content-Type: text/html\n\n";
print <<END_OF_HTML;
<HTML>
<HEAD>
<TITLE>About this server</TITLE>
</HEAD>
<BODY>
<h1>About this server</h1>
<hr>
<pre>
Server name: $ENV{SERVER_NAME}
Listening port: $ENV{SERVER_PORT}
Server Software: $ENV{SERVER_SOFTWARE}
Server Protocol: $ENV{SERVER_PROTOCOL}
CGI version: $ENV{GATEWAY_INTERFACE}
</pre>
<hr>
END_OF_HTML

my $var_name;
foreach $var_name (sort keys %ENV) {
  print "<p><b>$var_name</b><br/>";
  print $ENV{$var_name},"</p>";
}

print <<END_OF_HTML;
<hr>
</BODY>
</HTML>
END_OF_HTML
