#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 18;
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

$client->close;

is(test_error(sub { $xpl->main_loop(); }),
   "Serial device closed\n", 'dies on close');

{
  local $0 = 'dingus';
  local @ARGV = ('-v', '127.0.0.1:'.$port);
  $xpl = xPL::SerialClientLine->new(port => 0, hubless => 1,
                                    reader_callback => \&device_reader,
                                    baud => 9600,
                                    input_record_separator => '\\n',
                                    output_record_separator => '\n');
}
ok($xpl, 'created serial client');
is($xpl->input_record_separator, '\\n', 'input_record_separator set correctly');
is($xpl->output_record_separator, '\n',
   'output_record_separator set correctly');
ok(!$xpl->discard_buffer_check, 'no discard timeout');
