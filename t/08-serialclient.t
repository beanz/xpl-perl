#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 26;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::SerialClient');
use_ok('xPL::SerialClient::BinaryMessage');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

my $read = '';
my $written = '';
sub device_reader {
  my ($xpl, $buf, $last) = @_;
  $read .= $buf;
  $written = $last;
  return '123';
}
{
  local $0 = 'dingus';
  local @ARGV = ('-v', '127.0.0.1:'.$port);
  $xpl = xPL::SerialClient->new(port => 0, hubless => 1,
                                reader_callback => \&device_reader,
                                discard_buffer_timeout => 5,
                                baud => 9600,
                                name => 'dungis');
}
ok($xpl, 'created serial client');
is($xpl->device_id, 'dungis', 'device_id set correctly');
ok($sel->can_read, 'serial device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');

$xpl->write(xPL::SerialClient::BinaryMessage->new(raw => 'test',
                                                  desc => 'test'));

my $client_sel = IO::Select->new($client);
ok($client_sel->can_read, 'serial device ready to read');

my $buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size');
is($buf, 'test', 'content is correct');

print $client 'sent';

$xpl->main_loop(1);

is($read, 'sent', 'returned content is correct');
is(ref $written, 'xPL::SerialClient::BinaryMessage',
   'last sent data is correct type');
is($written, '74657374: test', 'last sent data is correct');

is($xpl->{_buf}, '123', 'returned buffer content is correct');

$xpl->write(xPL::SerialClient::BinaryMessage->new(hex => '31', data => 'data'));
$xpl->write('2');

is((sysread $client, $buf, 64), 1, 'read is correct size');
is($buf, '1', 'content is correct');

print $client 'sent again';
$read = '';
$xpl->{_last_read} -= 10; # trigger discard timeout
is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   "Discarding: 313233\n", 'correctly discarded old buffer');

is($read, 'sent again', 'returned content is correct');
is(ref $written, 'xPL::SerialClient::BinaryMessage',
   'last sent data is correct type');
is($written, '31', 'last sent data is correct');
is($written->data, 'data', 'last sent data has correct data value');

is($xpl->{_buf}, '123', 'returned buffer content is correct');

$xpl->{_last_read} = time + 2;
$xpl->discard_buffer_check();
is($xpl->{_buf}, '123', 'buffer content not discarded');

$client->close;

is(test_error(sub { $xpl->main_loop(); }),
   "Serial read failed: Connection reset by peer\n", 'dies on close');

ok(!defined xPL::SerialClient::BinaryMessage->new(desc => 'duff message'),
   'binary message must have either hex or raw supplied');

undef $device;
{
  local $0 = 'dingus';
  local @ARGV = ('-v', '127.0.0.1:'.$port);
  is(test_error(sub { $xpl = xPL::SerialClient->new(port => 0, hubless => 1) }),
     '', 'connection refused');
}
