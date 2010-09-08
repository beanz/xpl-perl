#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use POSIX qw/uname/;
use Socket;
use Test::More tests => 5;
$|=1;

use_ok("xPL::Hub");

my $hub = xPL::Hub->new(interface => 'lo', port => 0, verbose => 1);
is(scalar $hub->clients, 0, "no clients");

use_ok("xPL::Client");

my $dingus = xPL::Client->new(vendor_id => 'acme',
                              device_id => 'dingus',
                              instance_id => 'default',
                              ip => "127.0.0.1",
                              broadcast => "127.255.255.255",
                             );
# hacking the send socket to send to the hub
$dingus->{_send_sin} =
  sockaddr_in($hub->listen_port, inet_aton($hub->broadcast));

$dingus->send(class => 'hbeat.app',
              body => [ remote_ip => '127.0.0.2', port => 12345 ]);
$hub->main_loop(1);    # hub receives it
my @clients = $hub->clients;
is(scalar @clients, 0, "no clients");

$dingus->send(class => 'hbeat.end',
              body => [ remote_ip => '127.0.0.2', port => 12345 ]);
$hub->main_loop(1);    # hub receives it
@clients = $hub->clients;
is(scalar @clients, 0, "no clients");
