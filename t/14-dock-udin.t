#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 33;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','UDIN');


$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

my $count = 0;
{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--udin-verbose', '--udin-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--udin', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read, 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::UDIN', 'plugin has correct type');

# for synchronization
$plugin->{_ack_timeout_callback} = sub { $count++ };

my $buf;

ok($client_sel->can_read, 'device receive a message - ?');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - ?');
is($buf, "?\r", 'content is correct - ?');

wait_for_tick($xpl, $count);

my $msg = xPL::Message->new(class => 'control.basic',
                            head => { source => 'acme-udin.test' },
                            body =>
                            {
                             type => 'output',
                             device => 'o1',
                             current => 'high',
                            });
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read, 'device receive a message - o1/high');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - o1/high');
is($buf, "n1\r", 'content is correct - o1/high');

wait_for_tick($xpl, $count);

$msg->current('low');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read, 'device receive a message - o1/low');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - o1/low');
is($buf, "f1\r", 'content is correct - o1/low');

wait_for_tick($xpl, $count);
$msg->current('pulse');
$msg->device('o3');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read, 'device receive a message - o3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - o3/pulse');
is($buf, "n3\r", 'content is correct - o3/pulse');
wait_for_tick($xpl, $count);
ok($client_sel->can_read, 'device receive a message - o3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - o3/pulse');
is($buf, "f3\r", 'content is correct - o3/pulse');
wait_for_tick($xpl, $count);

$msg->current('toggle');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read, 'device receive a message - o3/toggle');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - o3/toggle');
is($buf, "t3\r", 'content is correct - o3/toggle');
wait_for_tick($xpl, $count);

$msg->current('invalid');
$msg->device('o4');
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   "Unsupported setting: invalid\n", 'device receive a message - o4/invalid');
# can read tested below

$msg->current('pulse');
$msg->device('oXX');
$xpl->dispatch_xpl_message($msg);
ok(!$client_sel->can_read(0.1), 'device received no message - invalid/pulse');

$msg->current('high');
$msg->device('debug');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read, 'device receive a message - debug/high');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - debug/high');
is($buf, "s0\r", 'content is correct - debug/high');
print $client "\r\n0\r\n"; # blank line should be ignored
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: '0'\n", 'read response - debug/high');

$plugin->{_verbose} = 0;
print $client "0\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', 'no response w/o verbose - debug/high');

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('--verbose', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'dingus'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --udin parameter is required
}, 'missing parameter');
}

sub wait_for_tick {
  my ($xpl, $current) = @_;
  while ($count == $current) {
    $xpl->main_loop(1);
  }
}
