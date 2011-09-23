#!/usr/bin/perl -w
#
# Copyright (C) 2009, 2010 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 72;
use t::Helpers qw/test_warn test_error test_output wait_for_callback/;
no warnings qw/deprecated/;
$|=1;

use_ok('xPL::Dock','DMX');
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
  local @ARGV = ('--interface', 'lo',
                 '--define', 'hubless=1', '--dmx-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock dmx client');
ok($sel->can_read(0.5), 'dmx device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DMX', 'plugin has correct type');

foreach my $color ('ff0000', '00ff00', '0000ff') {
  my $val = $color eq 'ff0000' ? 'red' : '0x'.$color;
  my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                              schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => 1,
                               type => 'set',
                               value => $val,
                              ]);
  $xpl->dispatch_xpl_message($msg);

  ok($client_sel->can_read(0.5), 'serial device ready to read - '.$color);

  my $buf = '';
  is((sysread $client, $buf, 64), 6, 'read is correct size - '.$color);
  my $m = xPL::IORecord::Hex->new(raw => $buf);
  is($m->str, '010001'.$color, 'content is correct - '.$color);

  print $client chr(0).(substr $buf, -1);

  is(test_output(sub {
                   wait_for_callback($xpl,
                                     input => $plugin->{_io}->input_handle)
                 }, \*STDOUT),
     "received: 00".(substr $m, -2)."\n", 'read response - '.$color);
  check_sent_msg({
                  message_type => 'xpl-trig',
                  schema => 'dmx.confirm',
                  body => [
                           base => 1,
                           type => 'set',
                           value => $val,
                          ],
                 }, 'dmx.confirm for '.$val);
}

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => '1x2',
                               type => 'set',
                               value => '0x0000ff',
                              ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - base=1x2');

my $buf = '';
is((sysread $client, $buf, 64), 9, 'read is correct size - base=1x2');
my $m = xPL::IORecord::Hex->new(raw => $buf);
is($m->str, '0100010000ff0000ff', 'content is correct - base=1x2');

print $client chr(0).(substr $buf, -1);

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00".(substr $m, -2)."\n", 'read response - base=1x2');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'dmx.confirm',
                body => [
                         base => '1x2',
                         type => 'set',
                         value => '0x0000ff',
                        ],
               }, 'dmx.confirm for 1x2=0x0000ff');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => '1x2',
                               type => 'set',
                               value => 'invalid',
                              ]);
$xpl->dispatch_xpl_message($msg);

ok(!$client_sel->can_read(0.1),
   'serial device nothing to read - invalid value');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => 'invalid',
                               type => 'set',
                               value => 'red',
                              ]);
$xpl->dispatch_xpl_message($msg);

ok(!$client_sel->can_read(0.1),
   'serial device nothing to read - invalid base');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => 'hex',
                               type => 'set',
                               value => '010001ff',
                              ]);
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - base=hex');

$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - base=hex');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m->str, '010001ff', 'content is correct - base=hex');

print $client chr(0).(substr $buf, -1);

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00".(substr $m, -2)."\n", 'read response - base=hex');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'dmx.confirm',
                body => [
                         base => 'hex',
                         type => 'set',
                         value => '010001ff',
                        ],
               }, 'dmx.confirm for hex=010001ff');

$plugin->{_min_visible_diff} = 64; # limit length of fade
$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => 1,
                               type => 'set',
                               value => '0xff0000',
                               fade => .1,
                              ]);
$xpl->dispatch_xpl_message($msg);

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'dmx.confirm',
                body => [
                         base => 1,
                         type => 'set',
                         value => '0xff0000',
                        ],
               }, 'dmx.confirm for 1=0xff0000');

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            schema => 'dmx.basic',
                              head => { source => 'acme-dmx.test' },
                              body =>
                              [
                               base => 4,
                               type => 'set',
                               value => '128,128',
                               fade => .3,
                              ]);
$xpl->dispatch_xpl_message($msg);

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'dmx.confirm',
                body => [
                         base => 4,
                         type => 'set',
                         value => '128,128',
                        ],
               }, 'dmx.confirm for 4=128,128');

my @expected = qw/0140 03bf 0180 037f 01c0 033f 01ff 0300 044040 048080/;
my $num = @expected;
$xpl->add_input(handle => $client,
                callback =>
                sub {
                  my $buf = '';
                  my $expected = shift @expected;
                  is((sysread $client, $buf, 64), 2+length($expected)/2,
                     'read is correct size - '.$expected);

                  my $m = xPL::IORecord::Hex->new(raw => $buf);
                  is($m->str, '0100'.$expected,
                     'content is correct - '.$expected);

                  print $client chr(0).(substr $buf, -1);

                  is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
                     "received: 00".(substr $m, -2)."\n",
                     'read response - '.$expected);
                }
               );

my $count = $xpl->input_callback_count($client);
while (1) {
  $xpl->main_loop(1);
  my $new_count = $xpl->input_callback_count($client);
  last if ($new_count >= $count + $num);
}

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
The --dmx-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, 'message as expected - '.$desc);
}

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo', '--rgb', 'non-existant-rgb-txt',
                 '--define', 'hubless=1', '--dmx-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock dmx client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DMX', 'plugin has correct type');
is((join ',', sort keys %{$plugin->{_rgb}}),
   'black,blue,cyan,green,magenta,red,white,yellow',
   'plugin loaded default colors');
