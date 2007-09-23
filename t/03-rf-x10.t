#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 25;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

is(xPL::RF::hex_dump('ABC'), '414243', 'hex_dump() function test');

is(test_error(sub { xPL::RF->new(); }),
   qq{xPL::RF->new: requires 'source' parameter\n},
   'xPL::RF requires source parameter');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost',
                      duplicate_timeout => 1);
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*', '4d14');
ok(!defined $res, 'ignores short message - version response');

$res = $rf->process_variable_length(pack 'H*', '2c');
ok(!defined $res, 'ignores short message - 2c response');

$res = $rf->process_variable_length(pack 'H*','00');
ok($res, 'recognizes valid length - 0-bit null');
is($res->{length}, 1, 'recognizes sufficient data - 0-bit null');
is(scalar @{$res->{messages}}, 0, 'array has no messages - 0-bit null');

$rf = xPL::RF->new(source => 'bnz-rfxcom.localhost', verbose => 1);
is(test_warn(sub { $res = $rf->process_variable_length(pack 'H*','100000'); }),
   "Unknown message, len=16:\n  0000\n", 'warning - 16-bit null');
ok($res, 'recognizes valid length - 16-bit null');
is($res->{length}, 3, 'recognizes sufficient data - 16-bit null');
is(scalar @{$res->{messages}}, 0, 'array has no messages - 16-bit null');

$res = $rf->process_variable_length(pack 'H*', '20649b');
ok($res, 'recognizes valid length w/insufficent data');
is($res->{length}, 0, 'recognizes insufficient data');

$res = $rf->process_32bit(pack 'H*','649b28d7');
ok($res, 'recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - off a11},
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

