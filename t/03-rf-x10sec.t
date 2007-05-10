#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 18;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*','29fef1807fb700');
is($res->{length}, 7, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'returns correct messages - 1');
is($res->{messages}->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *}.
   q{ - normal 127 delay=max},
   'returns correct messages - 2');

$res = $rf->process_32bit(pack 'H*','010e44bb');
ok($res, 'recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'returns correct messages - 1');
is($res->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *}.
   q{ - alert 128 tamper=true delay=min},
   'returns correct messages - 2');

$res = $rf->process_32bit(pack 'H*','010e45ba');
ok($res, 'recognizes valid message');
is($res->[0]->summary,
   q{xpl-trig/security.zone: bnz-rfxcom.localhost -> *},
   'returns correct messages - 1');
is($res->[1]->summary,
   q{xpl-trig/x10.security: bnz-rfxcom.localhost -> *}.
   q{ - alert 128 tamper=true lowbat=true delay=min},
   'returns correct messages - 2');

# not supported kr10 light on
is(test_warn(sub { $res = $rf->process_32bit(pack 'H*','010e46b9'); }),
   "Not supported: 62 KF574 lights on\n",
   'testing unsupported x10 security code');
ok($res, 'recognizes valid message');
is(scalar @$res, 0, 'array has no messages');

$res =
  $rf->process_32bit(pack 'H*','00f00003');
ok($res, 'recognizes valid message');
is(scalar @$res, 0, 'array has no messages');

$res = $rf->process_32bit(pack 'H*','01fe45ba');
ok($res, 'recognizes valid message - non-x10sec');
is(scalar @$res, 0, 'array has no messages - non-x10sec');
