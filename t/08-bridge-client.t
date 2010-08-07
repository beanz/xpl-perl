#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
use Socket;
use Time::HiRes;
use IO::Select;
use IO::Socket;
use POSIX qw/strftime/;
use Test::More tests => 12;
use t::Helpers qw/test_error test_warn/;

$|=1;

use_ok("xPL::Bridge");
use_ok("xPL::Message");

$ENV{XPL_HOSTNAME} = 'mytestid';

my $warn;
$SIG{__WARN__} = sub { $warn .= $_[0]; };

# fake a server bridge
my $ss = IO::Socket::INET->new(LocalHost => '127.0.0.1', LocalPort => 19_999,
                               Listen => 2, ReuseAddr => 1);
ok($ss, "created fake server bridge");
my $sel = IO::Select->new($ss);

my $bridge = xPL::Bridge->new(ip => "127.0.0.1",
                              broadcast => "127.255.255.255",
                              vendor_id => 'acme',
                              device_id => 'bridge',
                              bridge_port => 19_999,
                              remote_ip => '127.0.0.1',
                              verbose => 1);
is($bridge->remote_ip, '127.0.0.1', 'check default local ip address');
is($bridge->local_ip, undef, 'check default local ip address');

is(scalar $bridge->peers, 1, "remote bridges connected");

ok($sel->can_read(0.5), "remote bridge has connection to accept");
my $cs = $ss->accept();

my $msg = xPL::Message->new(head => { source => 'acme-clock.clepsydra' },
                            class => "clock.update",
                            body => { time => strftime("%Y%m%d%H%M%S",
                                                       localtime(time)) },
                           );
ok($msg, "prepared message to send from remote");
my $msg_str = $msg->string;
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)), "client sent message");

$bridge->main_loop(1);

my $md5 = xPL::Bridge::msg_hash($msg_str);

ok(exists $bridge->{_bridge}->{seen}->{$md5}, "message in cache");

$cs->close;
$bridge->verbose(0);

is(test_error(sub { $bridge->main_loop(1) }),
   'xPL::Bridge->sock_read: No one to talk to quitting.',
   'remote close error');

$ss->close;

like(test_error(sub {
                  $bridge = xPL::Bridge->new(ip => "127.0.0.1",
                                             broadcast => "127.0.0.1",
                                             vendor_id => 'acme',
                                             device_id => 'bridge',
                                             bridge_port => 19_999,
                                             remote_ip => '127.0.0.1',
                                             verbose => 1);
                }),
     qr/^xPL::Bridge->setup_client_mode: connect to remote peer failed:/,
   'connection to remote failed');
