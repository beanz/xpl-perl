#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
use Socket;
use Time::HiRes;
use IO::Select;
use IO::Socket;
use POSIX qw/strftime/;
use Test::More tests => 47;
use t::Helpers qw/test_error test_warn wait_for_callback/;
no warnings qw/deprecated/;

$|=1;

use_ok("xPL::Bridge");
use_ok("xPL::Message");

my $call;
{
  package My::Bridge;
  use base qw/xPL::Bridge/;
  sub sock_accept {
    my $self = shift;
    $call = \@_;
    $self->SUPER::sock_accept(@_);
  }
  1;
}

$ENV{XPL_HOSTNAME} = 'mytestid';

my $warn;
$SIG{__WARN__} = sub { $warn .= $_[0]; };

my $bridge = My::Bridge->new(ip => "127.0.0.1",
                             broadcast => "127.0.0.1",
                             vendor_id => 'acme',
                             device_id => 'bridge',
                             bridge_port => 19_999,
                             verbose => 1);
is($bridge->timeout, 120, 'default timeout');
is($bridge->bridge_mode, 'server', 'bridge mode');
is($bridge->local_ip, '0.0.0.0', 'check default local ip address');

is(join(",",$bridge->peers), "", "no client bridges initially");

# fake a client bridge
my $cs = IO::Socket::INET->new(PeerHost => '127.0.0.1', PeerPort => 19_999);
ok($cs, "created fake client bridge");
my $cport = $cs->sockport;
my $cstr = $cs->sockhost.':'.$cport;
my $sel = IO::Select->new($cs);

# run main loop for client to be accepted
wait_for_call($bridge);
undef $call;

is(scalar $bridge->peers, 1, "fake client accepted");

fake_hub_message($bridge,
                 message_type => 'xpl-stat',
                 head => { source => 'acme-clock.cuckoo' },
                 schema => "clock.update",
                 body => [ time => strftime("%Y%m%d%H%M%S", localtime(time)) ]);

# run main loop for message to be received and re-transmitted to clients
wait_for_callback($bridge, xpl_callback => '!bridge');

ok($sel->can_read(0.5), "client has first message to read");

my $buf = "";
ok($cs->sysread($buf, 1500), "received first message");

my $msg_str = xPL::Bridge::unpack_message($buf);
my $msg = xPL::Message->new_from_payload($msg_str);
ok($msg, "first message object");
is($msg->schema, 'clock.update', "first message class");
is($msg->source, 'acme-clock.cuckoo', "first message source");

$msg = xPL::Message->new(message_type => 'xpl-stat',
                         head => { source => 'acme-clock.clepsydra' },
                         schema => "clock.update",
                         body => [ time => strftime("%Y%m%d%H%M%S",
                                               localtime(time)) ]);
ok($msg, "prepared message to send from client");
$msg_str = $msg->string;
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)), "client sent message");
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)),
   "client sent message again");
$cs->flush();

wait_for_callback($bridge, input => ($bridge->peers)[0]);

my $md5 = xPL::Bridge::msg_hash($msg_str);

ok(exists $bridge->{_bridge}->{seen}->{$md5}, "message in cache");

$bridge->verbose(1);
fake_hub_message($bridge, $msg_str);
$bridge->main_loop(1);
ok(!$sel->can_read(0.2), "client has no message to read");
ok(exists $bridge->{_bridge}->{seen}->{$md5}, "message in cache");

fake_hub_message($bridge, $msg_str);
$bridge->main_loop(1);
ok(!$sel->can_read(0.2), "client still has no message to read");
ok(!exists $bridge->{_bridge}->{seen}->{$md5}, "message not in cache");

fake_hub_message($bridge, $msg_str);
$bridge->main_loop(1);
ok($sel->can_read(0.2), "client has message to read");

$msg = xPL::Message->new(message_type => 'xpl-stat',
                         head => { source => 'acme-clock.clepsydra', hop => 9 },
                         schema => "hbeat.basic");
ok($msg, "prepared message to send from client");
$msg_str = $msg->string;
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)),
   "client sent message w/hop=9");

my $w = test_warn(sub { $bridge->main_loop(1); });
$w=~s/\d+\.\d+\.\d+\.\d+/127.0.0.1/;
is($w,
   "Dropping msg from 127.0.0.1:$cport: xpl-stat
{
hop=10
source=acme-clock.clepsydra
target=*
}
hbeat.basic
{
}\n",
   'dropping message warning - remote');

ok($cs->syswrite(xPL::Bridge::pack_message("xpl-cmnd\n{}")),
   "client sent invalid message");

$w = test_warn(sub { $bridge->main_loop(1); });
$w=~s/\d+\.\d+\.\d+\.\d+/127.0.0.1/;
is($w,
   'My::Bridge->sock_read: Invalid message from 127.0.0.1:'.$cport.
     ': xPL::Message->new_from_payload: '.
     'Message badly formed: failed to split head and body',
   'invalid message warning');

fake_hub_message($bridge,
                 message_type => 'xpl-stat',
                 head => { source => 'acme-clock.cuckoo', hop => 9 },
                 schema => "hbeat.basic");
is(test_warn(sub { $bridge->main_loop(1); }),
   "Dropping local msg: xpl-stat/hbeat.basic: acme-clock.cuckoo -> * \n",
   'dropping message warning - local');

ok($cs->close, "fake client closed");
$bridge->main_loop(1);
is(join(",",$bridge->peers), "", "client bridges closed");

$cs = IO::Socket::INET->new(PeerHost => '127.0.0.1', PeerPort => 19_999);
ok($cs, "created fake client bridge");
$cstr = $cs->sockhost.':'.$cs->sockport;
$sel = IO::Select->new($cs);

# run main loop for client to be accepted
wait_for_call($bridge);
undef $call;

is(scalar $bridge->peers, 1, "fake client accepted");

ok($cs->close, "fake client closed");
$bridge->main_loop(1);
is(join(",",$bridge->peers), "", "client bridges closed");

ok(!xPL::Bridge::unpack_message('xxx'),
   "too short message - length truncated");
ok(!xPL::Bridge::unpack_message(pack 'Na*', 3, 'x'),
   "too short message - string truncated");

my $old_time = time-10;
my $not_so_old_time = time;
my $cache = $bridge->{_bridge}->{seen};
$cache->{'thisiswillbeemptied'} = [ $old_time ];
$cache->{'thisiswontbe'} = [ $old_time, $not_so_old_time ];
$cache->{'thisiswontbetouchedatall'} = [ $not_so_old_time ];
$bridge->dispatch_timer('!clean-seen-cache');
ok(!exists $cache->{'thisiswillbeemptied'}, "cleaning old cache entry");
ok(exists $cache->{'thisiswontbe'}, "not cleaning duplicate cache entry");
is(scalar @{$cache->{'thisiswontbe'}}, 1,
   "correct remaining cache entry 1 - length");
is($cache->{'thisiswontbe'}->[0], $not_so_old_time,
   "correct remaining cache entry 1 - content");
is(scalar @{$cache->{'thisiswontbetouchedatall'}}, 1,
   "correct remaining cache item 2 - length");
is($cache->{'thisiswontbetouchedatall'}->[0], $not_so_old_time,
   "correct remaining cache entry 2 - content");
ok(!$bridge->seen_cache_remove("non-existent-entry"),
   "non-existent entry is ignored");

is(test_error(sub {
     my $bridge = xPL::Bridge->new(ip => "127.0.0.1",
                                   broadcast => "127.0.0.1",
                                   vendor_id => 'acme',
                                   device_id => 'bridge',
                                   timeout => 1,
                                   bridge_port => 19_999);
   }),
   'xPL::Bridge->setup_server_mode: '.
     'bind to listen socket failed: Address already in use',
   'bind failure');

$bridge = $bridge->new(ip => "127.0.0.1", broadcast => "127.0.0.1",
                       vendor_id => 'acme', device_id => 'bridge',
                       local_ip => '127.0.0.1', timeout => 1);
is($bridge->timeout, 1, 'check timeout parameter');
is($bridge->bridge_port, 3_866, 'check default port');
is($bridge->local_ip, '127.0.0.1', 'check local ip address');

sub fake_hub_message {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  $xpl->send(@_);
  $xpl->{_send_sin} = $save_sin;
}

sub wait_for_call {
  my $xpl = shift;
  $xpl->main_loop(1) until (defined $call);
}
