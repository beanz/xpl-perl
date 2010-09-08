#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Socket;
use Time::HiRes;
use t::Helpers qw/test_error test_warn test_output/;
use Test::More tests => 14;
$|=1;

use_ok('xPL::Client');

my $xpl = xPL::Client->new(vendor_id => 'acme',
                           device_id => 'dingus',
                           ip => '127.0.0.1',
                           broadcast => '127.255.255.255',
                           stealth => 1,
                           port => 0,
                          );
ok($xpl, 'constructor');

is($xpl->hbeat_mode, undef, 'hbeat mode is standard');
is($xpl->{_listen_sock}, $xpl->{_send_sock}, 'listen socket is send socket');
is((unpack 'I', (getsockopt $xpl->{_listen_sock}, SOL_SOCKET, SO_REUSEADDR)), 1,
   'listen socket has SO_REUSEADDR set');
my $timeout;
my $msg;
$xpl->add_xpl_callback(id => 'xpl',
                       self_skip => 0,
                       callback => sub {
                         my %p = @_;
                         $msg = $p{message};
                         return 1;
                       });
$xpl->add_timer(id => 'timeout', callback => sub { $timeout++; 1 },
                timeout => 0.1);
$xpl->main_loop(1); # shouldn't send anything, should timeout
is($timeout, 1, 'correct timeout count');
is($xpl->hbeat_count, 0, 'correct hbeat count');
is($msg, undef, 'no message received');

$xpl->send_hbeat_end();
$xpl->main_loop(1); # shouldn't send anything, should timeout
is($timeout, 2, 'correct timeout count');
is($xpl->hbeat_count, 0, 'correct hbeat count');
is($msg, undef, 'no message received');

$xpl->main_loop(1); # shouldn't receive anything, should timeout
is($timeout, 3, 'correct timeout count');
is($xpl->hbeat_count, 0, 'correct hbeat count');
is($msg, undef, 'no message received');
