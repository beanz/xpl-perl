#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 56;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','VIOM');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--viom-verbose', '--viom-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--viom-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::VIOM', 'plugin has correct type');

my $buf;

ok($client_sel->can_read(0.5), 'device receive a message - CSV');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - CSV');
is($buf, "CSV\r\n", 'content is correct - CSV');
print $client "Software Version 1.02+1.01\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("Software Version 1.02+1.01\n".
    "sending: CIC1\n".
    "queued: COR\n".
    "queued: CIN\n"),
   'read response - CSV');

ok($client_sel->can_read(0.5), 'device receive a message - CIC1');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - CIC1');
is($buf, "CIC1\r\n", 'content is correct - CIC1');
print $client "Input Change Reporting is On\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Input Change Reporting is On\nsending: COR\n",
   'read response - CIC1');

ok($client_sel->can_read(0.5), 'device receive a message - COR');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - COR');
is($buf, "COR\r\n", 'content is correct - COR');
print $client "Output 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 Inactive\nsending: CIN\n",
   'read response - COR');

ok($client_sel->can_read(0.5), 'device receive a message - CIN');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - CIN');
is($buf, "CIN\r\n", 'content is correct - CIN');
print $client "Input 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Input 1 Inactive\n",
   'read response - CIN');

$plugin->{_verbose} = 0;
print $client "Input 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '',
   'read response - Input inactive(unchanged)');
$plugin->{_verbose} = 2;

print $client "Input 1 Active\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Input 1 Active\n",
   'read response - Input active(changed)');
# no message because it was regular update/sync not a status change
check_sent_msg(undef, , 'i01 high');

print $client "0000000000000000\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Sending i01 low\n0000000000000000\n",
   'read response - input changed state');
check_sent_msg({
                message_type => 'xpl-trig',
                class => 'sensor.basic',
                body =>
                [ device => 'i01', type => 'input', current => 'low' ],
               }, 'i01 low');

print $client "1000000000000000\r\n";
$plugin->{_verbose} = 0;
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', 'read response - input changed state');
check_sent_msg({
                message_type => 'xpl-trig',
                class => 'sensor.basic',
                body =>
                [ device => 'i01', type => 'input', current => 'high' ],
               }, 'i01 low');
$plugin->{_verbose} = 2;

my $msg = xPL::Message->new(class => 'control.basic',
                            head => { source => 'acme-viom.test' },
                            body =>
                            [
                             type => 'output',
                             device => 'o01',
                             current => 'high',
                            ]);
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/high');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/high');
is($buf, "XA1\r\n", 'content is correct - o01/high');
print $client "Output 1 On Period\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 On Period\n",
   'read response - o01/high');

$msg->current('low');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/low');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/low');
is($buf, "XB1\r\n", 'content is correct - o01/low');
print $client "Output 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 Inactive\n", 'read response - o01/low');

$msg->current('pulse');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/pulse');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/pulse');
is($buf, "XA1\r\n", 'content is correct - o01/pulse');
print $client "Output 1 On Period\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 On Period\nsending: XB1\n",
   'read response - o01/pulse');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/pulse');
is($buf, "XB1\r\n", 'content is correct - o01/pulse');
print $client "Output 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 Inactive\n", 'read response - o01/pulse');

$msg->current('toggle');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/toggle');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/toggle');
is($buf, "XA1\r\n", 'content is correct - o01/toggle');
print $client "\r\nOutput 1 On Period\r\n"; # extra new line should be ignored
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 On Period\n",
   'read response - o01/toggle');

$msg->current('toggle');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o01/toggle(off)');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - o01/toggle(off)');
is($buf, "XB1\r\n", 'content is correct - o01/toggle(off)');
print $client "Output 1 Inactive\r\n";
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "Output 1 Inactive\n",
   'read response - o01/toggle(off)');


$msg->device('invalid');
$xpl->dispatch_xpl_message($msg);
# tested by can_read below

$msg->device('o01');
$msg->current('invalid');
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   "Unsupported setting: invalid\n", 'device receive a message - o01/invalid');
ok(!$client_sel->can_read(0.01), 'device receive a message - o01/invalid');

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
The --viom-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while ((ref $msg->[0]) =~ /^xPL::Message::hbeat/) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $expected) {
    my %m = @{$msg};
    is_deeply(\%m, $expected, 'message as expected - '.$desc);
  } else {
    is(scalar @msg, 0, 'message not expected - '.$desc);
  }
}
