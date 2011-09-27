#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 33;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
no warnings qw/deprecated/;
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
                 '--udin-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::UDIN', 'plugin has correct type');

# for synchronization
$plugin->{_io}->{_ack_timeout_callback} = sub { $count++ };

my $buf;

ok($client_sel->can_read(0.5), 'device receive a message - ?');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - ?');
is($buf, "?\r", 'content is correct - ?');

wait_for_tick($xpl, $count);

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'control.basic',
                            head => { source => 'acme-udin.test' },
                            body =>
                            [
                             device => 'udin-r1',
                             type => 'output',
                             current => 'high',
                            ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - udin-r1/high');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - udin-r1/high');
is($buf, "n1\r", 'content is correct - udin-r1/high');

wait_for_tick($xpl, $count);

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'udin-r1',
                          type => 'output',
                          current => 'low',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - udin-r1/low');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - udin-r1/low');
is($buf, "f1\r", 'content is correct - udin-r1/low');

wait_for_tick($xpl, $count);
$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'udin-r3',
                          type => 'output',
                          current => 'pulse',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - udin-r3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - udin-r3/pulse');
is($buf, "n3\r", 'content is correct - udin-r3/pulse');
wait_for_tick($xpl, $count);
ok($client_sel->can_read(0.5), 'device receive a message - udin-r3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - udin-r3/pulse');
is($buf, "f3\r", 'content is correct - udin-r3/pulse');
wait_for_tick($xpl, $count);

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'udin-r3',
                          type => 'output',
                          current => 'toggle',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - udin-r3/toggle');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - udin-r3/toggle');
is($buf, "t3\r", 'content is correct - udin-r3/toggle');
wait_for_tick($xpl, $count);

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'udin-r4',
                          type => 'output',
                          current => 'invalid',
                         ]);
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   "Unsupported setting: invalid\n",
   'device receive a message - udin-r4/invalid');
# can read tested below

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'oXX',
                          type => 'output',
                          current => 'pulse',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok(!$client_sel->can_read(0.1), 'device received no message - invalid/pulse');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'control.basic',
                         head => { source => 'acme-udin.test' },
                         body =>
                         [
                          device => 'debug',
                          type => 'output',
                          current => 'high',
                         ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - debug/high');
$buf = '';
is((sysread $client, $buf, 64), 3, 'read is correct size - debug/high');
is($buf, "s0\r", 'content is correct - debug/high');
print $client "\r\n0\r\n"; # blank line should be ignored
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
   "received: '0'\n", 'read response - debug/high');

$plugin->{_verbose} = 0;
print $client "0\r\n";
is(test_output(sub {
                 wait_for_callback($xpl,
                                   input => $plugin->{_io}->input_handle)
               }, \*STDOUT),
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
The --udin-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub wait_for_tick {
  my ($xpl, $current) = @_;
  while ($count == $current) {
    $xpl->main_loop(1);
  }
}
