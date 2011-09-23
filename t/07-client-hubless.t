#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Socket;
use Time::HiRes;
use t::Helpers qw/test_error test_warn test_output/;
use Test::More tests => 19;
no warnings qw/deprecated/;
$|=1;

use_ok('xPL::Client');

my $xpl = xPL::Client->new(vendor_id => 'acme',
                           device_id => 'dingus',
                           ip => '127.0.0.1',
                           broadcast => '127.255.255.255',
                           hubless => 1,
                           port => 0,
                          );
ok($xpl, 'constructor');

is($xpl->hbeat_mode, 'standard', 'hbeat mode is standard');
is($xpl->{_listen_sock}, $xpl->{_send_sock}, 'listen socket is send socket');
is((unpack 'I', (getsockopt $xpl->{_listen_sock}, SOL_SOCKET, SO_REUSEADDR)), 1,
   'listen socket has SO_REUSEADDR set');
my $start_time = Time::HiRes::time;
my $msg;
my $end_time;
$xpl->add_xpl_callback(id => 'xpl',
                       self_skip => 0,
                       callback => sub {
                         my %p = @_;
                         $end_time = Time::HiRes::time;
                         $msg = $p{message};
                         return 1;
                       });
$xpl->main_loop(1); # send
is($xpl->hbeat_count, 1, 'correct hbeat count');
$xpl->main_loop(1); # receive
ok($msg, 'message arrived');
is($msg->schema, 'hbeat.basic',
   'hbeat.basic since no port ip information is needed');
is(int($end_time - $start_time), 0, 'message sent immediately');

my $xpl2 = xPL::Client->new(vendor_id => 'acme',
                            device_id => 'dungis',
                            ip => '127.0.0.1',
                            broadcast => '127.255.255.255',
                            hubless => 1,
                            port => $xpl->listen_port,
                           );
ok($xpl2, 'constructor');
undef $msg;
$xpl2->main_loop(1); # send
$xpl->main_loop(1); # receive
is($xpl->hbeat_count, 1, 'correct hbeat count');
is($xpl2->hbeat_count, 1, 'correct hbeat count');
ok($msg, 'message arrived');
is($msg->schema, 'hbeat.basic',
   'hbeat.basic since no port ip information is needed');
is($msg->source, $xpl2->id, 'received second clients hbeat.basic message');

undef $xpl;
undef $xpl2;

use_ok('xPL::Hub');
my $hub = xPL::Hub->new(ip => '127.0.0.1',
                        broadcast => '127.255.255.255',
                        port => 0);
ok($hub, 'hub created');

is(test_warn(sub {
               $xpl = xPL::Client->new(vendor_id => 'acme',
                                       device_id => 'dingus',
                                       ip => '127.0.0.1',
                                       broadcast => '127.255.255.255',
                                       hubless => 1,
                                       port => $hub->listen_port,
                                      );
             }), "bind failed ... switching off hubless mode.\n",
             'fallback to non-hubless if hub found');
ok($xpl, 'constructor');
