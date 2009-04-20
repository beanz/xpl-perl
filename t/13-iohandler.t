#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 22;
use IO::Select;
use IO::Socket::INET;
use t::Helpers qw/test_warn test_error test_output/;
use lib 't/lib';
$|=1;

use_ok('xPL::IOHandler');

my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp device');
my $sel = IO::Select->new($device);
my $port = $device->sockport();

my @input;
{
  package MockxPL;
  sub new {
    bless {}, shift;
  }
  sub add_input {
    my $self = shift;
    $self->{input} = { @_ };
  }
  sub exists_timer { 0 }
  1;
}

my $xpl = MockxPL->new();

my $read;
my $written;
my $return = 1;
sub device_reader {
  my ($handler, $obj, $last) = @_;
  $read = $obj;
  $written = $last;
  return $return;
}

my $count;
{
  package MyIOH;
  use base 'xPL::IOHandler';
  sub write_next {
    my $self = shift;
    $count++;
    $self->SUPER::write_next(@_);
  }
  1;
}

my $io = MyIOH->new(device => '127.0.0.1:'.$port,
                    reader_callback => \&device_reader,
                    discard_buffer_timeout => 5,
                    input_record_type => 'xPL::IORecord::LFLine',
                    xpl => $xpl);
ok($sel->can_read(0.5), 'serial device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');

print $client "test\n123";

my $cb = $xpl->{input}->{callback};
my $in = $xpl->{input}->{handle};
$cb->($in, $io);

is($read, 'test', 'read');
is($io->{_buffer}, '123', 'buffer');
is($count, 1, 'write_next called');

print $client "456";

$return = 0;
is(test_output(sub { $cb->($in, $io); }, \*STDERR), '', 'not discarding');
print $client "789\n";
is($count, 1, 'write_next not called');

$io->{_last_read} -= 10;
is(test_output(sub { $cb->($in, $io); }, \*STDERR),
   "Discarding: 313233343536\n", 'discarding');
is($read, '789', 'read');
is($io->{_buffer}, '', 'buffer');
is($count, 1, 'write_next not called (again)');

$client->close;
is(test_error(sub { $cb->($in, $io); }),
   'MyIOH->read: closed', 'dies on close');

$device->close;
is(test_error(sub {
                my $io = MyIOH->new(device => '127.0.0.1:'.$port,
                                    reader_callback => \&device_reader,
                                    xpl => $xpl);
              }),
   (q{MyIOH->device_open: TCP connect to '127.0.0.1:}.$port.
    q{' failed: Connection refused}), 'connection refused');

is(test_error(sub { xPL::IOHandler->new(input_record_type =>
                                          'xPL::IORecord::NonExistent') }),
   q{Can't locate xPL/IORecord/NonExistent.pm in @INC}, 'bad record type');


no warnings;
*{MyIOH::argh} = sub { my $self = shift; warn $self.': ',@_; };
use warnings;

my $warn =
  test_warn(sub {
              my $io = MyIOH->new(device => '/dev/just-a-test',
                                  baud => 9600,
                                  reader_callback => \&device_reader,
                                  xpl => $xpl);
            });

like($warn, qr{MyIOH: Setting serial port with stty failed}, 'stty failure');
like($warn, qr{MyIOH: open of '/dev/just-a-test' failed}, 'open failure');

$warn =
  test_warn(sub {
              my $io = MyIOH->new(device => '/dev/null',
                                  baud => 9600,
                                  reader_callback => \&device_reader,
                                  xpl => $xpl);
            });

like($warn, qr{MyIOH: Setting serial port with stty failed}, 'stty failure');
unlike($warn, qr{MyIOH: open of '[^']*' failed}, 'open worked');

$ENV{PATH} = 't/bin:'.$ENV{PATH};
my $err;
$warn =
  test_warn(sub {
              $err =
                test_output(sub {
                              my $io = MyIOH->new(device => '/dev/null',
                                                  baud => 9600,
                                                  reader_callback =>
                                                    \&device_reader,
                                                  xpl => $xpl);
                            }, \*STDERR) });

is($warn, undef, 'stty worked');
is($err, "-F /dev/null ospeed 9600 pass8 raw -echo\n", 'stty called correctly');

