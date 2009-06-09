#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Socket;
use Test::More tests => 10;
use Time::HiRes;
use t::Helpers qw/test_warn test_error/;
$|=1;

use_ok('xPL::Client');

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
my $buf = '';

my $warn;
$SIG{__WARN__} = sub { $warn .= $_[0]; };

my $xpl = xPL::Client->new(vendor_id => 'acme', device_id => 'ping',
                           instance_id => 'test', ip => "127.0.0.1",
                           broadcast => "127.255.255.255",
                          );
ok($xpl, 'constructor');

$xpl->{_send_sin} = sockaddr_in($fake_hub_port, $fake_hub_addr);

ok($xpl->exists_timer("!fast-hbeat"), "hbeat timer exists");
$xpl->remove_timer("!fast-hbeat");
ok(!$xpl->exists_timer("!fast-hbeat"), "hbeat timer removed");
$xpl->add_timer(id => '!tick', timeout => 0.001);

fake_hub_response($xpl, message_type => 'xpl-cmnd',
                  class => "ping.request");
$xpl->main_loop(1);
ok($xpl->exists_timer('!ping-response'), 'ping response timer created');
fake_hub_response($xpl, message_type => 'xpl-cmnd',
                  class => "ping.request");
$xpl->main_loop(1);
ok($xpl->exists_timer('!ping-response'), 'ping response timer still exists');
# TODO: should check that the timeout isn't reset
$xpl->reset_timer('!ping-response', time-6);
wait_for_tick($xpl, '!ping-response');
my $r = recv($hs, $buf, 1024, 0);
ok(defined $r, "received ping response");
my $msg = xPL::Message->new_from_payload($buf);
like($msg->summary,
   qr!^xpl-stat/ping\.response: acme-ping\.test -> \* - ok \d!,
   "ping response content");

sub wait_for_tick {
  my $xpl = shift;
  my $callback = shift;

  my $tn = $xpl->timer_next($callback);
  do { $xpl->main_loop(1); } until (Time::HiRes::time > $tn);
}

sub fake_hub_response {
  my $xpl = shift;
  my $save_sin = $xpl->{_send_sin};
  # hack send_sin so we can send some responses to ourself
  $xpl->{_send_sin} = sockaddr_in($xpl->listen_port, inet_aton($xpl->ip));
  my $msg = xPL::Message->new(head => {source => 'bnz-test.test' }, @_);
  ok($xpl->send($msg), 'sent '.$msg->summary);
  $xpl->{_send_sin} = $save_sin;
}
