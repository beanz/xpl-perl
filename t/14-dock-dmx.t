#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 86;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','DMX');
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
  local @ARGV = ('-v',
                 '--interface', 'lo',
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

my $msg = xPL::Message->new(class => 'dmx.basic',
                            head => { source => 'acme-dmx.test' },
                            body =>
                            {
                             type => 'set',
                             base => 1,
                             value => 'dummy',
                            });
foreach my $color ('ff0000', '00ff00', '0000ff') {
  my $val = $color eq 'ff0000' ? 'red' : '0x'.$color;
  $msg->value($val);
  $xpl->dispatch_xpl_message($msg);

  ok($client_sel->can_read(0.5), 'serial device ready to read - '.$color);

  my $buf = '';
  is((sysread $client, $buf, 64), 6, 'read is correct size - '.$color);
  my $m = xPL::BinaryMessage->new(raw => $buf);
  is($m, '010001'.$color, 'content is correct - '.$color);

  print $client chr(0).(substr $buf, -1);

  is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
     "received: 00".(substr $m, -2)."\n", 'read response - '.$color);
  check_sent_msg('dmx.confirm', $val, '1');
}

$msg->base('1x2');
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - base=1x2');

my $buf = '';
is((sysread $client, $buf, 64), 9, 'read is correct size - base=1x2');
my $m = xPL::BinaryMessage->new(raw => $buf);
is($m, '0100010000ff0000ff', 'content is correct - base=1x2');

print $client chr(0).(substr $buf, -1);

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00".(substr $m, -2)."\n", 'read response - base=1x2');

check_sent_msg('dmx.confirm', '0x0000ff', '1x2');

$msg->value('invalid');
$xpl->dispatch_xpl_message($msg);

ok(!$client_sel->can_read(0.1),
   'serial device nothing to read - invalid value');

$msg->value('red');
$msg->base('invalid');
$xpl->dispatch_xpl_message($msg);

ok(!$client_sel->can_read(0.1),
   'serial device nothing to read - invalid base');

$msg->base('hex');
$msg->value('010001ff');
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read(0.5), 'serial device ready to read - base=hex');

$buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size - base=hex');
$m = xPL::BinaryMessage->new(raw => $buf);
is($m, '010001ff', 'content is correct - base=hex');

print $client chr(0).(substr $buf, -1);

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00".(substr $m, -2)."\n", 'read response - base=hex');

check_sent_msg('dmx.confirm', '010001ff', 'hex');

$plugin->{_min_visible_diff} = 64; # limit length of fade
$msg->base('1');
$msg->value('0xff0000');
$msg->extra_field('fade', .1);
$xpl->dispatch_xpl_message($msg);

check_sent_msg('dmx.confirm', '0xff0000', '1');

$msg->base('4');
$msg->value('128,128');
$msg->extra_field('fade', .3);
$xpl->dispatch_xpl_message($msg);

check_sent_msg('dmx.confirm', '128,128', '4');

my @expected = qw/0140 03bf 0180 037f 01c0 033f 01ff 0300 044040 048080/;
my $num = @expected;
$xpl->add_input(handle => $client,
                callback =>
                sub {
                  my $buf = '';
                  my $expected = shift @expected;
                  is((sysread $client, $buf, 64), 2+length($expected)/2,
                     'read is correct size - '.$expected);

                  my $m = xPL::BinaryMessage->new(raw => $buf);
                  is($m, '0100'.$expected, 'content is correct - '.$expected);

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
  my ($class, $color, $base) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is($m{class}, 'dmx.confirm', 'dmx.confirm message sent - '.$color);
  is($m{body}->{value}, $color, 'dmx.confirm has correct value - '.$color);
  is($m{body}->{base}, $base, 'dmx.confirm has correct base - '.$color);
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
