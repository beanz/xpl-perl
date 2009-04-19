#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 29;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','EasyDAQ');

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

my $count = 0;
{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--easydaq-verbose', '--easydaq-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 # Test the required_field using @ARGV path
                 '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::EasyDAQ', 'plugin has correct type');

# for synchronization
$plugin->{_io}->{_ack_timeout_callback} = sub { $count++ };

my $buf;

ok($client_sel->can_read(0.5), 'device receive a message - 4200');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - 4200');
my $m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4200', 'content is correct - 4200');

wait_for_tick($xpl, $count);

my $msg = xPL::Message->new(class => 'control.basic',
                            head => { source => 'acme-easydaq.test' },
                            body =>
                            {
                             type => 'output',
                             device => 'o1',
                             current => 'high',
                            });
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o1/high');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - o1/high');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4301', 'content is correct - o1/high');

wait_for_tick($xpl, $count);

$msg->current('low');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o1/low');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - o1/low');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4300', 'content is correct - o1/low');

wait_for_tick($xpl, $count);
$msg->current('pulse');
$msg->device('o3');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - o3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - o3/pulse');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4304', 'content is correct - o3/pulse');
wait_for_tick($xpl, $count);
ok($client_sel->can_read(0.5), 'device receive a message - o3/pulse');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - o3/pulse');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4300', 'content is correct - o3/pulse');
wait_for_tick($xpl, $count);

$msg->current('toggle');
is(test_warn(sub { $xpl->dispatch_xpl_message($msg) }),
   "Unsupported setting: toggle\n", 'unsupported - o3/toggle');

$msg->current('pulse');
$msg->device('oXX');
$xpl->dispatch_xpl_message($msg);
ok(!$client_sel->can_read(0.1), 'device received no message - invalid/pulse');

$msg->current('high');
$msg->device('debug');
$xpl->dispatch_xpl_message($msg);
ok($client_sel->can_read(0.5), 'device receive a message - debug/high');
$buf = '';
is((sysread $client, $buf, 64), 2, 'read is correct size - debug/high');
$m = xPL::IORecord::Hex->new(raw => $buf);
is($m, '4100', 'content is correct - debug/high');
print $client chr(0);
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   "received: 00\n", 'read response - debug/high');

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
The --easydaq-tty parameter is required
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

sub wait_for_tick {
  my ($xpl, $current) = @_;
  while ($count == $current) {
    $xpl->main_loop(1);
  }
}
