#!/usr/bin/perl -w

##############################################################################
#                                                                            #
# Copyright 2006, Andy Davidson (andy@nosignal.org)                          #
#                                                                            #
# This program is free software; you can redistribute it and/or modify       #
# it under the terms of the GNU General Public License as published by       #
# the Free Software Foundation; either version 2 of the License, or          #
# any later version.                                                         #
#                                                                            #
# This program is distributed in the hope that it will be useful,            #
# but WITHOUT ANY WARRANTY; without even the implied warranty of             #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the              #
# GNU General Public License for more details.                               #
#                                                                            #
##############################################################################

use strict;
use IO::Socket;
use Getopt::Std;
use File::Tail;
use threads;

$SIG{'PIPE'} = 'IGNORE';

my %options=();
getopts("p:f:",\%options);
if (!$options{p})
  {
    die "You have to tell me a port to connect to - use logsock.pl -p 1234 to bind to port 1234";
  }

my %logfiles=();
if (!$options{f})
  {
    print localtime() . " No logfile config file defined.  Dunno what you want to tail.  Starting anyway.\n";
  } else {
    open my $conffile, '<', $options{f} or die "Can't open config file specified with -f - $!";
    while (<$conffile>)
      {
        chomp;
        next if $_ =~ /^\#/; # config comments start with a #
        my ($tag,$logfile) = split (/,/, $_);
        if (-e $logfile)
          {
            $logfiles{$tag} = $logfile;
            print localtime() . " Adding config file $logfile with tag $tag\n";
          } else {
            print localtime() . " FAILED to add config file $logfile with tag $tag\n";
          }
      }
    close $conffile;
  }

my @menus = keys %logfiles;
my $hostname = `cat /etc/hostname`;
chomp ($hostname);

my $sock = new IO::Socket::INET ( LocalPort => $options{p},
                                  Proto     => "tcp",
                                  Listen    => 10,
                                  Reuse     => 1);
die "Did not bind to port $options{p} and create server, call 999 and ask for the Coastguard." unless $sock;
print localtime() . " Server up ... [bound to port $options{p} and accepting clients]\n";

eval 
  { 
    threads->create( \&ClientConnect, $sock->accept, )->detach while 1;
  };
print "ERR: $@" if $@;

sub ClientConnect
  { 
    my $client = shift;
    $client->autoflush(1);
    printf localtime() . " [Connect from %s]\n", $client->peerhost;
    print  $client "Andylog server on $hostname.  'menu' for logs, 'help' for commands.\r\n";
    while (<$client>) 
      {
        next unless /\S/;       # ignore blank line
        s/[\n\r]*$//;           # chomp() was only stripping the CR not the LF
        if (/quit|exit/i) 
          {
            last;
          } 
        elsif (/date|time/i) 
          {
            printf $client "Time on this server (%s) is %s\r\n", $hostname, scalar localtime;
            next;
          } 
        elsif (/menu/i)
          {
            foreach (@menus) { print $client $_ ." "; } 
            print $client "\r\n";
            next;
          }
        elsif (/help/i)
          {
            print $client "menu time exit\r\n";
            next;
          }
        elsif (/cow/i)
          {
             print $client &Moo . "\r\n";
          }
        my $request = $_;
        if (defined($logfiles{$request}))
          { 
            print $client "Trapped request - $logfiles{$request}\r\n";
            print localtime() . "Client " . $client->peerhost . " requests $logfiles{$request}\n";
            my $file = File::Tail->new( name        => $logfiles{$request},
                                        interval    => 0,
                                        tail        => 5,
                                        maxinterval => 1,
                                        adjustafter => 2000,
                                        errmode     => "return"
                                      ) or printf $client "Could not open log file\n";
                while (my $line=$file->read)
                  {
                    if (defined($client))
		      {
                        print $client $line or die $!;
		      } else {
                        print "client has gone away\n";
		      }
                  }
              print "Client lost ($@)\n" if $@;

            next;
          }
      }
    print $client "Damn Hippy.\r\n";
    print localtime() . " " . $client->peerhost . " signing off.\n";
    close $client;
  }

sub Moo
  {
    return ' 
        ______________
       < happy easter >
        --------------
               \   ^__^
                \  (oo)\_______
                   (__)\       )\/\
                       ||----w |
                       ||     ||
           ';
  }
