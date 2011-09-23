#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use POSIX qw/uname/;
use Socket;
use Test::More tests => 70;
use t::Helpers qw/test_error test_warn/;
no warnings qw/deprecated/;
$|=1;

use_ok("xPL::Hub");

my $hub = xPL::Hub->new(interface => 'lo', port => 0);

my @methods =
  (
   [ 'ip', "127.0.0.1", ],
   [ 'broadcast', "127.0.0.1", ],
   [ 'port', '0', ],
  );
foreach my $rec (@methods) {
  my ($method, $value) = @$rec;
  is($hub->$method, $value, "$method method");
}

is(scalar $hub->clients, 0, "no clients");

is(test_warn(sub { $hub->listen_addr('none'); }),
   ref($hub)."->listen_addr: called with an argument, ".
     "but listen_addr is readonly",
   "setting readonly attribute - listen_addr");

use_ok("xPL::Client");

my $xpl = xPL::Client->new(vendor_id => 'acme',
                           device_id => 'dingus',
                           instance_id => 'default',
                           ip => "127.0.0.1",
                           broadcast => "127.255.255.255",
                          );

@methods =
  (
   [ 'vendor_id', 'acme', ],
   [ 'device_id', 'dingus', ],
   [ 'instance_id', 'default', ],
   [ 'id', "acme-dingus.default", ],
   [ 'ip', "127.0.0.1", ],
   [ 'broadcast', "127.255.255.255", ],
  );
foreach my $rec (@methods) {
  my ($method, $value) = @$rec;
  is($xpl->$method, $value, "$method method");
}

foreach my $m (qw/id vendor_id device_id
                  hbeat_interval fast_hbeat_interval
                  hopeful_hbeat_interval hub_response_timeout
                  hbeat_mode
                  listen_addr
                  /) {
  is(test_warn(sub { $xpl->$m('none'); }),
     ref($xpl)."->$m: called with an argument, but $m is readonly",
     "setting readonly attribute - ".$m);
}

is(test_warn(sub { $hub->client_attrib('none', 'attrib', 'value'); }),
   "xPL::Hub->item_attrib: client item 'none' not registered",
   'setting client attribute for invalid client');

is(test_warn(sub { $hub->remove_client('none') }),
   "xPL::Hub->remove_item: client item 'none' not registered",
   "removing invalid client");

# hacking the send socket to send to the hub
$xpl->{_send_sin} =
  sockaddr_in($hub->listen_port, inet_aton($hub->broadcast));

ok($xpl->exists_timer("!fast-hbeat"), "fast hbeat setup");
ok($xpl->exists_xpl_callback("!hub-found"), "hub found callback setup");
$xpl->main_loop(1);
$hub->main_loop(1);

my $client = $xpl->ip.':'.$xpl->listen_port;
my @clients = $hub->clients;
is(scalar @clients, 1, "one clients");
is($clients[0], $client, "the client");
ok($hub->exists_client($client), "the client exists");
is($hub->client_interval($client), 5, "the client interval");
is($hub->client_identity($client), "acme-dingus.default", "client identity");
like($hub->client_info($client),
     qr/acme-dingus.default i=5 l@\d\d:\d\d/, "client info");

is(test_warn(sub { $hub->add_client($client) }),
   "xPL::Hub->add_client: adding already registered client: $client",
   "adding duplicate client");

$xpl->main_loop(1);
ok($xpl->exists_timer("!hbeat"), "hbeat setup");

my $last = $hub->client_attrib($client, 'last');
sleep 1;
ok($xpl->send_hbeat(), "sending another hbeat");
$hub->main_loop(1);
my $last2 = $hub->client_attrib($client, 'last');
is($last2, $last+1, "last time incremented");

$xpl->send(message_type => "xpl-stat", schema => "hbeat.blah",
           body =>
           [
            interval => $xpl->hbeat_interval,
            port => $xpl->listen_port,
            remote_ip => $xpl->ip,
           ],
          );
$hub->main_loop(1);
$last2 = $hub->client_attrib($client, 'last');
is($last2, $last+1, "last time not incremented by non-hbeat");

ok($xpl->send_hbeat_end(), "sending hbeat end");
$hub->main_loop(1);

is(scalar $hub->clients, 0, "no clients again");
ok(!$hub->exists_client($client), "the client doesn't exists");

# fake a client
use_ok('xPL::Message');
my $id = 'bnz-client.test';
my $fake = '127.0.0.1:9999';
my $msg = xPL::Message->new(message_type => 'xpl-stat',
                            schema => 'hbeat.app',
                            head => { source => $id },
                            body =>
                            [
                             remote_ip => '127.0.0.1',
                             port => '9999',
                            ],
                            );
$hub->add_client($fake, $msg);
$hub->client_last($fake, time - 3*5*60); # make it old
$hub->client_interval($fake, 5);
$hub->client_identity($fake, $id);
is(scalar $hub->clients, 1, "one fake client");

# trigger client clean up job to timeout a second ago
$hub->timer_next('!clean', time-1);

$hub->main_loop(1);
is(scalar $hub->clients, 0, "fake client cleaned up");

$hub->add_client($fake, $msg);
$hub->client_last($fake, time - 2*5*60); # make it recent
$hub->client_interval($fake, 5);
$hub->client_identity($fake, $id);
is(scalar $hub->clients, 1, "one fake client");

# trigger client clean up job to timeout a second ago
$hub->timer_next('!clean', time-1);

$hub->main_loop(1);
is(scalar $hub->clients, 1, "fake client not cleaned up");

$hub->client_last($fake, time - 3*5*60); # make it old
$hub->verbose(1);
$hub->timer_next('!clean', time-1);
$hub->main_loop(1);
is(scalar $hub->clients, 0, "fake client cleaned up - verbose mode");


my ($port, $addr) = sockaddr_in(getsockname($xpl->{_send_sock}));

$xpl->send("junk message\n");
my $w = test_warn(sub { $hub->main_loop(1); });
$w=~s/\d+\.\d+\.\d+\.\d+/127.0.0.1/;
is($w,
   "Invalid message from 127.0.0.1:$port: ".
     "xPL::Message->new_from_payload: Message badly formed: ".
     "failed to split head and body",
   "hub handles duff message");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255");
   }),
   "xPL::Client->new: requires 'vendor_id' parameter",
   "client missing vendor_id parameter");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme');
   }),
   "xPL::Client->new: requires 'device_id' parameter",
   "client missing device_id parameter");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'thisistoolong');
   }),
  "xPL::Client->new: vendor_id invalid",
   "client invalid vendor_id parameter");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'thisistoolong');
   }),
   "xPL::Client->new: device_id invalid",
   "client invalid device_id parameter");

is($xpl->instance_id('fred'), 'fred', "client accepts valid instance_id");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'thisinstanceidistoolong');
   }),
   "xPL::Client->new: instance_id, thisinstanceidistoolong, is invalid.\n".
   "The default can be overridden by setting the XPL_HOSTNAME environment\n".
   "variable",
   "client invalid instance_id parameter");

is(test_warn(sub { $xpl->instance_id('thisinstanceidistoolong'); }),
   "xPL::Client->instance_id: invalid instance_id 'thisinstanceidistoolong'",
   "client invalid instance_id parameter");

is($xpl->instance_id, substr('thisinstanceidistoolong',0,12),
   "client truncates instance_id appropriately");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hbeat_interval => 3);
   }),
   "xPL::Client->new: hbeat_interval is invalid: ".
     "should be 5 - 30 (minutes)",
   "client invalid hbeat_interval parameter - too low");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hbeat_interval => 33);
   }),
   "xPL::Client->new: hbeat_interval is invalid: ".
     "should be 5 - 30 (minutes)",
   "client invalid hbeat_interval parameter - too high");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hbeat_interval => 'dead');
   }),
   "xPL::Client->new: hbeat_interval is invalid: ".
     "should be 5 - 30 (minutes)",
   "client invalid hbeat_interval parameter - nonsense");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                fast_hbeat_interval => 1);
   }),
   "xPL::Client->new: fast_hbeat_interval is invalid: ".
     "should be 3 - 30 (seconds)",
   "client invalid fast_hbeat_interval parameter - too low");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                fast_hbeat_interval => 120);
   }),
   "xPL::Client->new: fast_hbeat_interval is invalid: ".
     "should be 3 - 30 (seconds)",
   "client invalid fast_hbeat_interval parameter - too high");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                fast_hbeat_interval => 'dead');
   }),
   "xPL::Client->new: fast_hbeat_interval is invalid: ".
     "should be 3 - 30 (seconds)",
   "client invalid fast_hbeat_interval parameter - nonsense");


is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hopeful_hbeat_interval => 5);
   }),
   "xPL::Client->new: hopeful_hbeat_interval is invalid: ".
     "should be 20 - 300 (seconds)",
   "client invalid hopeful_hbeat_interval parameter - too low");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hopeful_hbeat_interval => 600);
   }),
   "xPL::Client->new: hopeful_hbeat_interval is invalid: ".
     "should be 20 - 300 (seconds)",
   "client invalid hopeful_hbeat_interval parameter - too high");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hopeful_hbeat_interval => 'dead');
   }),
   "xPL::Client->new: hopeful_hbeat_interval is invalid: ".
     "should be 20 - 300 (seconds)",
   "client invalid hopeful_hbeat_interval parameter - nonsense");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hub_response_timeout => 5);
   }),
   "xPL::Client->new: hub_response_timeout is invalid: ".
     "should be 30 - 300 (seconds)",
   "client invalid hub_response_timeout parameter - too low");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hub_response_timeout => 600);
   }),
   "xPL::Client->new: hub_response_timeout is invalid: ".
     "should be 30 - 300 (seconds)",
   "client invalid hub_response_timeout parameter - too high");

is(test_error(sub {
     my $new = xPL::Client->new(ip => "127.0.0.1",
                                broadcast => "127.255.255.255",
                                vendor_id => 'acme',
                                device_id => 'dingus',
                                instance_id => 'fred',
                                hub_response_timeout => 'forever');
   }),
   "xPL::Client->new: hub_response_timeout is invalid: ".
     "should be 30 - 300 (seconds)",
   "client invalid hub_response_timeout parameter - nonsense");

SKIP: {
  my $uname = (uname)[1];
  skip "uname isn't usable", 2 unless ($uname);
  $uname =~ s/\..*$//; # strip domain name
  delete $ENV{XPL_HOSTNAME};
  my $xpl = xPL::Client->new(vendor_id => 'acme',
                             device_id => 'dingus',
                             ip => "127.0.0.1",
                             broadcast => "127.255.255.255",
                            );
  ok($xpl, "constructor using uname for id");
  is($xpl->instance_id, $uname, "identity is from uname");
};

$xpl = $xpl->new(vendor_id => 'acme',
                 device_id => 'dingus',
                 instance_id => 'default',
                 ip => "127.0.0.1",
                 broadcast => "127.255.255.255",
                );
ok($xpl, "Constructor from blessed reference - not recommended");
