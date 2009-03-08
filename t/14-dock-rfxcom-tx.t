#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 75;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','RFXComTX');
use_ok('xPL::BinaryMessage');

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
                 '--rfxcom-tx-verbose',
                 '--define', 'hubless=1',
                 '--rfxcom-tx', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read, 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::RFXComTX', 'plugin has correct type');

ok($client_sel->can_read, 'device receive a message - F030F030');
my $buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - F030F030');
my $m = xPL::BinaryMessage->new(raw => $buf);
is($m, 'f030f030', 'content is correct - F030F030');
print $client pack 'H*', '10';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("received: 10\n".
    "sending: F037F037: variable length mode w/o receiver connected\n"),
   'read response - F030F030');

ok($client_sel->can_read, 'device receive a message - F037F037');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - F037F037');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, 'f037f037', 'content is correct - F037F037');
print $client pack 'H*', '37';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("received: 37\n".
    "sending: F03FF03F: disabling x10\n"),
   'read response - F037F037');

ok($client_sel->can_read, 'device receive a message - f03ff03f');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - f03ff03f');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, 'f03ff03f', 'content is correct - f03ff03f');
print $client pack 'H*', '37';
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n",
   'read response - f03ff03f');

my $msg = xPL::Message->new(strict => 0,
                            class => 'x10.basic',
                            head => { source => 'acme-x10.test' },
                            body =>
                            {
                             command => 'on',
                             device => 'a1,xxx',
                            });
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - a1/on');

$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - a1/on');

# TOFIX: should send confirm messages
#my $msg_str = $msg->string;
#$msg_str =~ s/basic/confirm/;
#check_sent_msg($msg_str);

$msg->extra_field(repeat => 2);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - a1/on');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\nsending: 20609f00ff: a1 on\n", 'read response - a1/on');

ok($client_sel->can_read, 'serial device ready to read - a1/on');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - a1/on');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '20609f00ff', 'content is correct - a1/on');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - a1/on');


$msg = xPL::Message->new(class => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         {
                          command => 'all_lights_off',
                          house => 'p',
                         });
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - p/all_lights_off');

$msg->extra_field(repeat => 2);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\nsending: 2030cf807f: p all_lights_off\n",
   'read response - p/all_lights_off');

ok($client_sel->can_read, 'serial device ready to read - p/all_lights_off');
$buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size - p/all_lights_off');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '2030cf807f', 'content is correct - p/all_lights_off');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - p/all_lights_off');


$msg = xPL::Message->new(strict => 0,
                         class => 'x10.basic',
                         head => { source => 'acme-x10.test' },
                         body =>
                         {
                          command => 'on',
                         });
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   ("Invalid x10.basic message:\n".
    "  xpl-cmnd/x10.basic: acme-x10.test -> * - on\n"),
   'invalid x10.basic message');


$msg = xPL::Message->new(class => 'homeeasy.basic',
                         head => { source => 'acme-homeeasy.test' },
                         body =>
                         {
                          command => 'off',
                          address => '0x31f8177',
                          unit => '10',
                         });
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - homeeasy');

$msg->extra_field(repeat => 2);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("received: 37\n".
    "sending: 21c7e05dca00: ".
    "xpl-cmnd/homeeasy.basic: acme-homeeasy.test -> * - off/0x31f8177 10\n"),
   'read response - homeeasy');

ok($client_sel->can_read, 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '21c7e05dca00', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - homeeasy');

$msg = xPL::Message->new(class => 'homeeasy.basic',
                         head => { source => 'acme-homeeasy.test' },
                         body =>
                         {
                          command => 'preset',
                          address => '0x31f8177',
                          unit => '10',
                          level => 10,
                         });
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - homeeasy');
$buf = '';
is((sysread $client, $buf, 64), 6, 'read is correct size - homeeasy');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '24c7e05dcaa0', 'content is correct - homeeasy');

print $client pack 'H*', '37';

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 37\n", 'read response - homeeasy');


$msg = xPL::Message->new(strict => 0,
                         class => 'homeeasy.basic',
                         head => { source => 'acme-he.test' },
                         body =>
                         {
                         });
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   ("Invalid homeeasy.basic message:\n".
   "  xpl-cmnd/homeeasy.basic: acme-he.test -> * - \n"),
   'invalid homeeasy.basic message');

$msg = xPL::Message->new(strict => 0,
                         class => 'homeeasy.basic',
                         head => { source => 'acme-he.test' },
                         body =>
                         {
                          command => 'preset',
                          address => '0x31f8177',
                          unit => '10',
                         });
is(test_warn(sub { $xpl->dispatch_xpl_message($msg); }),
   ("homeeasy.basic 'preset' message is missing 'level':\n".
    "  xpl-cmnd/homeeasy.basic: acme-he.test -> * - preset/0x31f8177 10\n"),
   'invalid homeeasy.basic message - preset w/o level');


$plugin->{_ack_timeout} = 0.1;
$plugin->{_receiver_connected} = 1;
$plugin->write(xPL::BinaryMessage->new(hex => 'f03ff03f', desc => 'no x10'));
ok($client_sel->can_read, 'serial device ready to read - no ack');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - no ack');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, 'f03ff03f', 'content is correct - no ack');
is(test_output(sub { $xpl->main_loop(1) }, \*STDERR), "No ack!\n", 'no ack');
ok($client_sel->can_read, 'serial device ready to read - no ack');
$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - no ack');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, 'f033f033', 'content is correct - no ack');

$client->close;

my @expected = split /\n/, q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
queued: F030F030: init/version check
sending: F030F030: init/version check
queued: F033F033: variable length mode w/receiver connected
queued: F03CF03C: enabling harrison
queued: F03DF03D: enabling klikon-klikoff
queued: F03EF03E: enabling flamingo
};

{
  local $0 = 'dingus';
  local @ARGV = ('-v', '--interface', 'lo',
                 '--rfxcom-tx-verbose',
                 '--define', 'hubless=1',
                 '--receiver-connected',
                 '--x10', '--harrison', '--koko', '--flamingo',
                 '--rfxcom-tx', '127.0.0.1:'.$port);
  my $output = test_output(sub { $xpl = xPL::Dock->new(port => 0) }, \*STDOUT);
  is_deeply([split /\n/, $output], \@expected, 'all options output');
}
ok($xpl, 'created dock client');
ok($sel->can_read, 'device ready to accept');
$client = $device->accept;
ok($client, 'client accepted');
$client_sel = IO::Select->new($client);


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
The --rfxcom-tx parameter is required
}, 'missing parameter');
}

sub check_sent_msg {
  my ($string) = @_;
  my $msg = shift @msg;
  while ((ref $msg->[0]) =~ /^xPL::Message::hbeat/) {
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
