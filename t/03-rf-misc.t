#!/usr/bin/perl -w
#
# Copyright (C) 2007, 2009 by Mark Hindess

use strict;
use Test::More tests => 32;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

is(xPL::RF::hex_dump('ABC'), '414243', 'hex_dump() function test');

my $rf = xPL::RF->new(duplicate_timeout => 1);
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*', '4d14');
ok(!defined $res, 'ignores short message - version response');

$res = $rf->process_variable_length(pack 'H*', '2c');
ok(!defined $res, 'ignores short message - 2c response');

$res = $rf->process_variable_length(pack 'H*','00');
ok($res, 'recognizes valid length - 0-bit null');
is($res->{length}, 1, 'recognizes sufficient data - 0-bit null');
is($res->{messages}, undef, 'no messages - 0-bit null');

$rf = xPL::RF->new(verbose => 1);
is(test_warn(sub { $res = $rf->process_variable_length(pack 'H*','100000'); }),
   "Unknown message, len=16:\n  0000\n", 'warning - 16-bit null');
ok($res, 'recognizes valid length - 16-bit null');
is($res->{length}, 3, 'recognizes sufficient data - 16-bit null');
is($res->{messages}, undef, 'no messages - 16-bit null');

$res = $rf->process_variable_length(pack 'H*', '20649b');
ok($res, 'recognizes valid length w/insufficent data');
is($res->{length}, 0, 'recognizes insufficient data');

$res = $rf->process_32bit(pack 'H*','649b28d7');
ok($res, 'recognizes valid message');
my %args = %{$res->[0]};
my $msg = xPL::Message->new(head => {source => 'bnz-rfxcom.localhost'},
                            message_type => 'xpl-trig', %args);

is($msg->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * off/a11},
   'returns correct messages - 1');

$res = $rf->process_32bit(pack 'H*','649b28d7');
ok($res, 'recognizes valid message - duplicate');
is(scalar @{$res}, 0, 'returns no messages - duplicate');

$res =
  $rf->process_32bit(pack 'H*','00f00003');
ok($res, 'recognizes valid message');
is(scalar @$res, 0, 'array has no messages');

$res = $rf->process_32bit(pack 'H*','01fe45ba');
ok($res, 'recognizes valid message - non-x10sec');
is(scalar @$res, 0, 'array has no messages - non-x10sec');

$res = $rf->process_32bit(pack 'H*','010e45fa');
ok($res, 'recognizes valid message - non-x10sec');
is(scalar @$res, 0, 'array has no messages - non-x10sec');

$res = $rf->process_variable_length(pack 'H*', '2201136f90f0');
ok($res, 'homeeasy command recognized');
is(scalar @{$res->{messages}}, 1, 'homeeasy.basic message generated');

$res = $rf->process_variable_length(pack 'H*', '2201136f90c0');
ok($res, 'duplicate homeeasy command recognized');
is(scalar @{$res->{messages}}, 0,
   'homeeasy.basic message for dup not generated');

# to get coverage of the short circuit for parsing in Oregon plugin.
is(test_warn(sub { $res = $rf->process_variable_length(pack 'H*','0710'); }),
   "Unknown message, len=7:\n  10\n", 'short unrecognized - warning');
ok($res, 'short unrecognized but valid command');
is($res->{length}, 2, 'short unrecognized but valid command - two bytes');
is($res->{messages}, undef,
   'short unrecognized but valid command - no messages');
