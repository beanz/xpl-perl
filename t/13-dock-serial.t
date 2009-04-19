#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 35;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','Serial');
use_ok('xPL::BinaryMessage');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

my $read = '';
my $written = '';
sub device_reader {
  my ($plugin, $buf, $last) = @_;
  $read .= $buf;
  $written = $last;
  return '123';
}
{
  local $0 = 'dingus';
  local @ARGV = ('-v', '--baud', '9600', '--device', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0, hubless => 1,
                        reader_callback => \&device_reader,
                        discard_buffer_timeout => 5,
                        name => 'dungis');
}
ok($xpl, 'created dock serial client');
is($xpl->device_id, 'dungis', 'device_id set correctly');
ok($sel->can_read(0.5), 'serial device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Serial', 'plugin has correct type');
$plugin->write(xPL::BinaryMessage->new(raw => 'test',
                                                  desc => 'test'));

my $client_sel = IO::Select->new($client);
ok($client_sel->can_read(0.5), 'serial device ready to read');

my $buf = '';
is((sysread $client, $buf, 64), 4, 'read is correct size');
is($buf, 'test', 'content is correct');

print $client 'sent';

$xpl->main_loop(1);

is($read, 'sent', 'returned content is correct');
is(ref $written, 'xPL::BinaryMessage',
   'last sent data is correct type');
is($written, '74657374: test', 'last sent data is correct');

is($plugin->buffer, '123', 'returned buffer content is correct');

$plugin->write(xPL::BinaryMessage->new(hex => '31',
                                                     data => 'data'));
$plugin->write('2');

is((sysread $client, $buf, 64), 1, 'read is correct size');
is($buf, '1', 'content is correct');

print $client 'sent again';
$read = '';
$plugin->{_last_read} -= 10; # trigger discard timeout
is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   "Discarding: 313233\n", 'correctly discarded old buffer');

is($read, 'sent again', 'returned content is correct');
is(ref $written, 'xPL::BinaryMessage',
   'last sent data is correct type');
is($written, '31', 'last sent data is correct');
is($written->data, 'data', 'last sent data has correct data value');

is($plugin->buffer, '123', 'returned buffer content is correct');

$xpl->{_last_read} = time + 2;
$plugin->discard_buffer_check();
is($plugin->buffer, '123', 'buffer content not discarded');

$client->close;

is(test_error(sub { $xpl->main_loop(); }),
   'xPL::Dock::Serial->serial_read: failed: Connection reset by peer',
   'dies on close');

ok(!defined xPL::BinaryMessage->new(desc => 'duff message'),
   'binary message must have either hex or raw supplied');

$device->close;
{
  local @ARGV = ('-v',
                 '--device' => '127.0.0.1:'.$port);
  is(test_error(sub {
                  $xpl = xPL::Dock->new(port => 0, hubless => 1,
                                        name => 'dingus')
                }),
     q{xPL::Dock::Serial->device_open: TCP connect to '127.0.0.1:}.$port.
     q{' failed: Connection refused}, 'connection refused');
}

{
  local @ARGV = ('-v',
                 '--device' => '/dev/just-a-test');
  no warnings;
  *{xPL::Dock::Serial::argh} =
    sub { my $self = shift; warn ref($self).": ",@_; };
  use warnings;
  my $warn = test_warn(sub {
                         $xpl = xPL::Dock->new(port => 0, hubless => 1,
                                               name => 'dingus')
                       });
  like($warn,
       qr{^xPL::Dock::Serial: Setting serial port with stty failed},
       'stty failure');
  like($warn,
       qr{xPL::Dock::Serial: open of '/dev/just-a-test' failed},
       'open failure');

  @ARGV = ('-v', '--device' => '/dev/null');
  $warn = test_warn(sub {
                         $xpl = xPL::Dock->new(port => 0, hubless => 1,
                                               name => 'dingus')
                       });
  like($warn,
       qr{^xPL::Dock::Serial: Setting serial port with stty failed},
       'stty failure');
  unlike($warn,
       qr{xPL::Dock::Serial: open of '[^']*' failed},
       'open worked');

  $ENV{PATH} = 't/bin:'.$ENV{PATH};
  @ARGV = ('-v', '--device' => '/dev/null');
  my $err;
  $warn =
    test_warn(sub {
                $err =
                  test_output(sub {
                                $xpl = xPL::Dock->new(port => 0, hubless => 1,
                                                      name => 'dingus')
                              }, \*STDERR) });
  is($warn, undef, 'stty worked');
  is($err, "-F /dev/null ospeed 9600 pass8 raw -echo\n",
     'stty called correctly');
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
The --device parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}
