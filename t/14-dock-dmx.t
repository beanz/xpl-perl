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

use_ok('xPL::Dock','DMX');
use_ok('xPL::BinaryMessage');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v', '--define', 'hubless=1', '--dmx', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock dmx client');
ok($sel->can_read, 'dmx device ready to accept');
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
  $msg->value('0x'.$color);
  $xpl->dispatch_xpl_message($msg);

  ok($client_sel->can_read, 'serial device ready to read - '.$color);

  my $buf = '';
  is((sysread $client, $buf, 64), 6, 'read is correct size - '.$color);
  my $m = xPL::BinaryMessage->new(raw => $buf);
  is($m, '010001'.$color, 'content is correct - '.$color);

  print $client chr(0).(substr $buf, -1);

  is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
     "received: 00".(substr $m, -2)."\n", 'read response - '.$color);
}

$msg->base('1x2');
$xpl->dispatch_xpl_message($msg);

ok($client_sel->can_read, 'serial device ready to read - base=1x2');

my $buf = '';
is((sysread $client, $buf, 64), 9, 'read is correct size - base=1x2');
my $m = xPL::BinaryMessage->new(raw => $buf);
is($m, '0100010000ff0000ff', 'content is correct - base=1x2');

print $client chr(0).(substr $buf, -1);

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00".(substr $m, -2)."\n", 'read response - base=1x2');



$plugin->{_min_visible_diff} = 64; # limit length of fade
$msg->base('1');
$msg->value('0xff0000');
$msg->extra_field('fade', .1);
$xpl->dispatch_xpl_message($msg);

$msg->base('4');
$msg->value('128,128');
$msg->extra_field('fade', .3);
$xpl->dispatch_xpl_message($msg);

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

my $cmd = $^X.' -Iblib/lib '.($ENV{HARNESS_PERL_SWITCHES}||'').
              ' blib/script/xpl-dmx';
my $fh;

open $fh, $cmd.' 2>&1 |' or die $!;
is(~~<$fh>, "The --dmx parameter is required\n", 'missing parameter content');
ok(!close $fh, 'missing parameter exit close');
