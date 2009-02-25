#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 16;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::SerialClientLine');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

my $read = '';
my $written = '';
sub device_reader {
  my ($xpl, $line, $last) = @_;
  $read .= $line."\n";
  $written .= $last;
  return '123';
}
{
  local $0 = 'dingus';
  local @ARGV = ('127.0.0.1:'.$port);
  $xpl = xPL::SerialClientLine->new(port => 0, hubless => 1,
                                    reader_callback => \&device_reader,
                                    discard_buffer_timeout => 5);
}
ok($xpl, 'created serial client');
is($xpl->device_id, 'dingus', 'device_id set correctly');
ok($sel->can_read, 'serial device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');

$xpl->write('test');

my $client_sel = IO::Select->new($client);
ok($client_sel->can_read, 'serial device ready to read');

my $buf = '';
is((sysread $client, $buf, 64), 5, 'read is correct size');
is($buf, "test\r", 'content is correct');

print $client "sent\n123";

$xpl->main_loop(1);

is($read, "sent\n", 'returned content is correct');
is($written, 'test', 'last sent data is correct');

$xpl->write('1');
$xpl->write('2');

is((sysread $client, $buf, 64), 2, 'read is correct size');
is($buf, "1\r", 'content is correct');

print $client "sent again\r\n";
$read = ''; $written = '';
$xpl->{_last_read} -= 10; # trigger discard timeout
is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   "Discarding: 313233\n", 'correctly discarded old buffer');

is($read, "sent again\n", 'returned content is correct');
is($written, '1', 'last sent data is correct');

$client->close;

is(test_error(sub { $xpl->main_loop(); }),
   "Serial read failed: Connection reset by peer\n", 'dies on close');
