#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 28;
use Time::HiRes;
use Cwd;
use t::Helpers qw/test_warn test_error test_output/;
no warnings qw/deprecated/;
$|=1;

use_ok('xPL::Dock','APCUPS');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
  my $msg;
  if (scalar @_ == 1) {
    $msg = shift;
  } else {
    eval {
      my %p = @_;
      $p{head}->{source} = $self->id if ($self->can('id') &&
                                         !exists $p{head}->{source});
      $msg = xPL::Message->new(%p);
      # don't think this can happen: return undef unless ($msg);
    };
    $self->argh("message error: $@") if ($@);
  }
  $msg;
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp apcups client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--apcups-verbose',
                 '--apcups-server' => '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock apcups client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::APCUPS', 'plugin has correct type');

ok(!$sel->can_read(0.2), 'apcups device not ready to accept');


$xpl->main_loop(1);

ok($sel->can_read(0.2), 'apcups device ready to accept - 1');
my $client = $device->accept;
ok($client, 'client accepted - 1');
my $client_sel = IO::Select->new($client);

ok($client_sel->can_read(0.2), 'apcups client sent data');
my $buf = '';
is((sysread $client, $buf, 512), 8, 'apcups client data length');
is((unpack 'n/a*', $buf), 'status', 'apcups client data content');

$client->print(pack 'n/a*', 'LINEV    : 239.0 Volts');
$client->print(pack 'n/a*', 'STATUS   : ONLINE');
$client->print(pack 'n/a*', 'TIMELEFT :  31.0 Minutes');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("mytestid-linev/voltage/239.0\n".
    "mytestid-status[status]=mains (ONLINE)\n".
    "mytestid-timeleft/generic/1860/s\n"),
   'log output');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-linev',
                 type => 'voltage',
                 current => '239.0',
                ],
               }, 'checking xPL message - linev');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-timeleft',
                 type => 'generic',
                 current => '1860',
                 units => 's',
                ],
               }, 'checking xPL message - timeleft');

$client->print(pack 'n/a*', 'LINEV    : 239.0 Volts');
$client->print(pack 'n/a*', 'STATUS   : ONLINE');
$client->print(pack 'n/a*', 'TIMELEFT :  31.0 Minutes');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', 'log output - no changes/no output');

check_sent_msg({
                message_type => 'xpl-stat',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-linev',
                 type => 'voltage',
                 current => '239.0',
                ],
               }, 'checking xPL message - linev');

check_sent_msg({
                message_type => 'xpl-stat',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-timeleft',
                 type => 'generic',
                 current => '1860',
                 units => 's',
                ],
               }, 'checking xPL message - timeleft');

$client->print(pack 'n/a*', 'CABLE    : USB Cable'); # silently ignored
$client->print(pack 'n/a*', 'LINEV    : 240.0 Volts');
$client->print(pack 'n/a*', 'STATUS   : ONBATT');
$client->print(pack 'n/a*', 'TIMELEFT :  20.0 Minutes');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   ("mytestid-linev/voltage/240.0\n".
    "mytestid-status[status]=battery (ONBATT)\n".
    "mytestid-timeleft/generic/1200/s\n"),
   'log output');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-linev',
                 type => 'voltage',
                 current => '240.0',
                ],
               }, 'checking xPL message - linev');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'ups.basic',
                body =>
                [
                 status => 'battery',
                 event => 'onbattery',
                ],
               }, 'checking xPL message - ups');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-timeleft',
                 type => 'generic',
                 current => '1200',
                 units => 's',
                ],
               }, 'checking xPL message - timeleft');

my $str = pack 'n/a* n/a*', '', 'LINEV    : 241.0 Volts';
$client->print(substr $str, 0, 4, '');
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', # nothing
   'log output - partial 1');
$client->print(substr $str, 0, 4, '');
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   '', # nothing
   'log output - partial 2');
$client->print($str);
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "mytestid-linev/voltage/241.0\n",
   'log output - remainder');

check_sent_msg({
                message_type => 'xpl-trig',
                schema => 'sensor.basic',
                body =>
                [
                 device => 'mytestid-linev',
                 type => 'voltage',
                 current => '241.0',
                ],
               }, 'checking xPL message - linev');

$client->print(pack "C C/a*", 0x1, 'test');
is(test_warn(sub { $xpl->main_loop(1); }), "Invalid string? 010474657374\n",
   'invalid string');

$client->close;

is(test_warn(sub { $xpl->main_loop(1) }),
   undef, 'connection closes silently');

$device->close;

is(test_warn(sub { $xpl->dispatch_timer('apcups'); }),
   ("Failed to contact apcups daemon at 127.0.0.1:".$port.
    ": Connection refused\n"),
   'connection failed');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while (ref $msg->[0]) {
    $msg = shift @msg; # skip hbeat.* message
  }
  my %m = @{$msg};
  is_deeply(\%m, $expected, $desc);
}
