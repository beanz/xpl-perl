#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 9;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res =
  $rf->process_variable_length(pack 'H*','2000f007cd');
is($res->{length}, 5, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rfsensor00f0[temp]=7.5},
   'returns correct message');

$res =
  $rf->process_variable_length(pack 'H*','2002f23ea1');
is($res->{length}, 5, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
   q{xpl-trig/sensor.basic: bnz-rfxcom.localhost}.
     q{ -> * - rfsensor02f2[voltage]=5.01},
   'returns correct message');

$res =
  $rf->process_variable_length(pack 'H*','2001f11ae5');
is($res->{length}, 5, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
   q{xpl-trig/sensor.basic: bnz-rfxcom.localhost}.
     q{ -> * - rfsensor01f1[voltage]=2.15},
   'returns correct message');
is($res->{messages}->[1]->summary,
   q{xpl-trig/sensor.basic: bnz-rfxcom.localhost}.
     q{ -> * - rfsensor01f1[humidity]=43.41},
   'returns correct message');
