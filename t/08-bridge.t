#!/usr/bin/perl -w
use strict;
use Socket;
use Time::HiRes;
use IO::Select;
use IO::Socket;
use Test::More tests => 31;
$|=1;

use_ok("xPL::Bridge");
use_ok("xPL::Message");

$ENV{XPL_HOSTNAME} = 'mytestid';

# we bind a fake hub to make sure we don't accidentally hit a live
# udp port
my $hs;
socket($hs, PF_INET, SOCK_DGRAM, getprotobyname('udp'));
setsockopt $hs, SOL_SOCKET, SO_BROADCAST, 1;
#setsockopt $hs, SOL_SOCKET, SO_REUSEADDR, 1;
binmode $hs;
bind($hs, sockaddr_in(0, inet_aton("127.0.0.1"))) or
  die "Failed to bind listen socket: $!\n";
my ($fake_hub_port, $fake_hub_addr) = sockaddr_in(getsockname($hs));

my $warn;
$SIG{__WARN__} = sub { $warn .= $_[0]; };

my $bridge = xPL::Bridge->new(ip => "127.0.0.1",
                              broadcast => "127.255.255.255",
                              vendor_id => 'acme',
                              device_id => 'bridge',
                              bridge_port => 19_999);


is(join(",",$bridge->peers), "", "no client bridges initially");

# fake a client bridge
my $cs = IO::Socket::INET->new(PeerHost => '127.0.0.1', PeerPort => 19_999);
ok($cs, "created fake client bridge");
my $cstr = $cs->sockhost.':'.$cs->sockport;
my $sel = IO::Select->new($cs);

# run main loop for client to be accepted
$bridge->main_loop(1);

is(join(",",map { $bridge->peer_name($_) } $bridge->peers),
   $cstr, "fake client accepted");

fake_hub_message($bridge,
                 head => { source => 'acme-clock.cuckoo' },
                 class => "clock.update");

# run main loop for message to be received and re-transmitted to clients
$bridge->main_loop(1);

ok($sel->can_read(0.5), "client has first message to read");

my $buf = "";
ok($cs->sysread($buf, 1500), "received first message");

my $msg_str = xPL::Bridge::unpack_message($buf);
my $msg = xPL::Message->new_from_payload($msg_str);
ok($msg, "first message object");
is($msg->class, 'clock', "first message class");
is($msg->class_type, 'update', "first message class_type");
is($msg->source, 'acme-clock.cuckoo', "first message source");

$msg = xPL::Message->new(head => { source => 'acme-clock.clepsydra' },
                         class => "clock.update");
ok($msg, "prepared message to send from client");
$msg_str = $msg->string;
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)), "client sent message");
ok($cs->syswrite(xPL::Bridge::pack_message($msg_str)),
   "client sent message again");

$bridge->main_loop(1);

my $md5 = xPL::Bridge::msg_hash($msg_str);

ok(exists $bridge->{_bridge}->{seen}->{$md5}, "message in cache");

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


sub fake_hub_message {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  $xpl->send(@_);
  $xpl->{_send_sin} = $save_sin;
}
