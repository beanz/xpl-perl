#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 89;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

is(xPL::RF::hex_dump('ABC'), '414243', 'hex_dump() function test');

is(test_error(sub { xPL::RF->new(); }),
   qq{xPL::RF->new: requires 'source' parameter\n},
   'xPL::RF requires source parameter');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*', '4d14');
ok(!defined $res, 'processing ignores short message - version response');

$res = $rf->process_variable_length(pack 'H*', '2c');
ok(!defined $res, 'processing ignores short message - 2c response');

$res = $rf->process_variable_length(pack 'H*', '2d');
ok(!defined $res, 'processing ignores bogus short message - 2d');

$res = $rf->process_variable_length(pack 'H*', '20649b');
ok($res, 'processing recognizes valid length');
is($res->{length}, 0, 'processing recognizes insufficient data');

$rf = xPL::RF->new(source => 'bnz-rfxcom.localhost',
                   duplicate_timeout => 1);
ok($rf, 'RF constructor - long duplicate timeout');
$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - off a11},
   'processing returns correct message');
$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is(scalar @{$res->{messages}}, 0, 'processing does not return duplicate');

# wait for duplicate entry to expire
select undef, undef, undef, 1.1;
$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - off a11},
   'processing returns correct message');
$res = $rf->process_variable_length(pack 'H*', '20649b08f7');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - on a11},
   'processing returns correct message');

$res = $rf->process_variable_length(pack 'H*', '20649b9867');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - dim a11},
   'processing returns correct message');

$res = $rf->process_variable_length(pack 'H*', '20649b8877');
ok($res, 'processing recognizes valid length');
is($res->{length}, 5, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - bright a11},
   'processing returns correct message');


$res = $rf->process_variable_length(pack 'H*','3000f00006000a');
ok($res, 'processing recognizes valid length');
is($res->{length}, 7, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rfxpower.00[energy]=15.36},
   'processing returns correct message');

$res = $rf->process_variable_length(pack 'H*','3000f000000000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 7, 'processing recognizes sufficient data');

$res = $rf->process_variable_length(pack 'H*','30000000000000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 7, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is(scalar @{$res->{messages}}, 0, 'processing array has no messages');

$res = $rf->process_variable_length(pack 'H*','100000');
ok($res, 'processing recognizes valid length');
is($res->{length}, 3, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is(scalar @{$res->{messages}}, 0, 'processing array has no messages');

$res = $rf->process_variable_length(pack 'H*','00');
ok($res, 'processing recognizes valid length');
is($res->{length}, 1, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is(scalar @{$res->{messages}}, 0, 'processing array has no messages');

$res =
  $rf->process_variable_length(pack 'H*','29fef1807fb700');
ok($res, 'processing recognizes valid length');
is($res->{length}, 7, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 1');
is($res->{messages}->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 2');

$res =
  $rf->process_32bit(pack 'H*','fef1807f');
ok($res, 'processing recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 1');
is($res->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 2');

$res =
  $rf->process_32bit(pack 'H*','010e44bb');
ok($res, 'processing recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 1');
is($res->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 2');

$res =
  $rf->process_32bit(pack 'H*','010e45ba');
ok($res, 'processing recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 1');
is($res->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *},
   'processing returns correct messages - 2');

# not supported kr10 light on
is(test_warn(sub { $res = $rf->process_32bit(pack 'H*','010e46b9'); }),
   "Not supported: 62 KF574 lights on\n",
   'testing unsupported x10 security code');
ok($res, 'processing recognizes valid message');
is(ref($res), 'ARRAY', 'processing returns array of messages');
is(scalar @$res, 0, 'processing array has no messages');

$res =
  $rf->process_32bit(pack 'H*','00f00003');
ok($res, 'processing recognizes valid message');
is(ref($res), 'ARRAY', 'processing returns array of messages');
is(scalar @$res, 0, 'processing array has no messages');

$res =
  $rf->process_variable_length(pack 'H*','78ea00a642000000169bff5f1dc05408');
ok($res, 'processing recognizes valid length');
is($res->{length}, 16, 'processing recognizes sufficient data');
ok($res->{messages}, 'processing returns messages');
is(ref($res->{messages}), 'ARRAY', 'processing returns array of messages');
is($res->{messages}->[0]->summary,
  'xpl-trig/sensor.basic: '.
   'bnz-rfxcom.localhost -> * - electrisave.a6[current]=6.6',
   'processing returns correct message');
