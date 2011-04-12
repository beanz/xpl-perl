#!#!/usr/bin/perl -w
#
# Copyright (C) 2009, 2010 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output wait_for_callback
                  wait_for_variable /;
use lib 't/lib';
$|=1;

BEGIN {
  require Test::More;
  eval { require AnyEvent::RFXCOM::TX; import AnyEvent::RFXCOM::TX; };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::RFXCOM::TX module: '.$@;
  }
  import Test::More tests => 71;
}

$ENV{DEVICE_RFXCOM_BASE_DEBUG} = 1;

$ENV{XPL_PLUGIN_TO_WRAP} = 'xPL::Dock::RFXComTX';
use_ok('xPL::Dock','Wrap');
use_ok('xPL::IORecord::Hex');

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
  local @ARGV = ('-v', '--interface', 'lo',
                 '--rfxcom-tx-verbose', '--no-x10',
                 '--define', 'hubless=1',
                 '--rfxcom-tx-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Wrap', 'plugin has correct type');

AnyEvent->one_event;
AnyEvent->one_event;

ok($client_sel->can_read(0.5), 'device receive a message - F030F030');
my $buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - F030F030');
my $m = xPL::IORecord::Hex->new(raw => $buf);
is($m, 'f030f030', 'content is correct - F030F030');
print $client pack 'H*', '10';
is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 10\n",
   'read response - F030F030');

ok($client_sel->can_read(0.5), 'device receive a message - f03ff03f');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - f03ff03f');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, 'f03ff03f', 'content is correct - f03ff03f');
print $client pack 'H*', '37';
is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - f03ff03f');

ok($client_sel->can_read(0.5), 'device receive a message - F037F037');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - F037F037');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, 'f037f037', 'content is correct - F037F037');
print $client pack 'H*', '37';
is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - F037F037');

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'x10.basic',
                            head => { source => 'acme-x10.test' },
                            body =>
                            [
                             command => 'on',
                             device => 'a1,xxx',
                            ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - a1/on');

$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n", 'read response - a1/on');

# TOFIX: should send confirm messages
#my $msg_str = $msg->string;
#$msg_str =~ s/basic/confirm/;
#check_sent_msg($msg_str);

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         [
                          command => 'on',
                          device => 'a1,xxx',
                          repeat => 2,
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - a1/on');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n", 'read response - a1/on');

ok($client_sel->can_read(0.5), 'serial device ready to read - a1/on');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n", 'read response - a1/on');


$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         [
                          command => 'all_lights_off',
                          house => 'p',
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n", 'read response - p/all_lights_off');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         [
                          command => 'all_lights_off',
                          house => 'p',
                          repeat => 2,
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - p/all_lights_off');

ok($client_sel->can_read(0.5), 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - p/all_lights_off');


$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         [
                          command => 'on',
                         ]);
like(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
     qr/Device::RFXCOM::Encoder::X10=.*->encode: Invalid x10 message/,
     'invalid x10.basic message');


$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'homeeasy.basic',
                         head => { source => 'acme-homeeasy.test' },
                         body =>
                         [
                          command => 'off',
                          address => '0x31f8177',
                          unit => '10',
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - homeeasy');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'homeeasy.basic',
                         head => { source => 'acme-homeeasy.test' },
                         body =>
                         [
                          command => 'off',
                          address => '0x31f8177',
                          unit => '10',
                          repeat => 2,
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - homeeasy');

ok($client_sel->can_read(0.5), 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n",
   'read response - homeeasy');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'homeeasy.basic',
                         head => { source => 'acme-homeeasy.test' },
                         body =>
                         [
                          command => 'preset',
                          address => '0x31f8177',
                          unit => '10',
                          level => 10,
                         ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '24c7e05dcaa0', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { wait_for_message() }, \*STDOUT),
   "Received: 37\n", 'read response - homeeasy');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'homeeasy.basic',
                         head => { source => 'acme-he.test' },
                         body => []);
like(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
     qr/Device::RFXCOM::Encoder::HomeEasy=.*->encode: Invalid homeeasy message/,
     'invalid homeeasy.basic message');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         schema => 'homeeasy.basic',
                         head => { source => 'acme-he.test' },
                         body =>
                         [
                          command => 'preset',
                          address => '0x31f8177',
                          unit => '10',
                         ]);
like(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
     qr/Device::RFXCOM::Encoder::HomeEasy=.*->encode: Invalid homeeasy message/,
     'invalid homeeasy.basic message - preset w/o level');


SKIP: {
  skip 'broken tests', 7;

  $plugin->{_ack_timeout} = 0.1;
  $plugin->{_receiver_connected} = 1;
  $plugin->{_io}->write(xPL::IORecord::Hex->new(hex => 'f03ff03f',
                                                desc => 'no x10'));
  ok($client_sel->can_read(0.5), 'serial device ready to read - no ack');
  $buf = '';
  is((sysread $client, $buf, 64), 4, 'read is correct size - no ack');
  $m = xPL::IORecord::Hex->new(raw => $buf);
  is($m, 'f03ff03f', 'content is correct - no ack');
  is(test_output(sub {
                   wait_for_variable($xpl, \$plugin->{_reset_device});
                 }, \*STDERR),
     "No ack!\n", 'no ack');
  ok($client_sel->can_read(0.5), 'serial device ready to read - no ack');
  $buf = '';
  is((sysread $client, $buf, 64), 4, 'read is correct size - no ack');
  $m = xPL::IORecord::Hex->new(raw => $buf);
  is($m, 'f033f033', 'content is correct - no ack');
}

$client->close;

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('-v', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'dingus'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --rfxcom-tx-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub check_sent_msg {
  my ($string) = @_;
  my $msg = shift @msg;
  while ($msg->[0] && ref $msg->[0] eq 'xPL::Message' &&
         $msg->[0]->schema =~ /^hbeat\./) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $string) {
    my $m = $msg->[0];
    is_deeply([split /\n/, $m->string], [split /\n/, $string],
              'message as expected - '.$m->summary);
  } else {
    is(scalar @msg, 0, 'message not expected');
  }
}

sub wait_for_message {
  my ($self) = @_;
  undef $plugin->{_got_message};
  do {
    AnyEvent->one_event;
  } until ($plugin->{_got_message});
}
