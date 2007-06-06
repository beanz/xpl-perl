#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 18;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res =
  $rf->process_variable_length(pack 'H*','2000f007cd');
is($res->{length}, 5, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rfsensor00f0[temp]=7.75},
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
     q{ -> * - rfsensor01f1[humidity]=41.83},
   'returns correct message');

# clear unit code cache and try again
$rf->stash('rfxsensor_cache', {});
# clear duplicate cache to avoid hitting it
$rf->{_cache} = {};
# set the voltage but not the temperature and get the relative humidity again
$res = $rf->process_variable_length(pack 'H*','2002f23ea1');

is(test_warn(sub { $res =
                     $rf->process_variable_length(pack 'H*','2001f11ae5');
                 }),
   qq{Don't have temperature for rfsensor01f1/00f0 yet - assuming 25'C\n},
   q{assuming 25'c warning});
is($res->{length}, 5, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
   q{xpl-trig/sensor.basic: bnz-rfxcom.localhost}.
     q{ -> * - rfsensor01f1[voltage]=2.15},
   'returns correct message');
is($res->{messages}->[1]->summary,
   q{xpl-trig/sensor.basic: bnz-rfxcom.localhost}.
     q{ -> * - rfsensor01f1[humidity]=43.41},
   'returns correct message');


# clear unit code cache and try again
$rf->stash('rfxsensor_cache', {});
# clear duplicate cache to avoid hitting it
$rf->{_cache} = {};
is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','2001f11ae5') }),
   qq{Don't have supply voltage for rfsensor01f1/00f0 yet\n},
   'no supply voltage reported');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','2003f31ae1') }),
   qq{Unsupported RFXSensor: type=3\n},
   'unknown sensor type');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','2003f30217') }),
   qq{RFXSensor info rfsensor03f3: battery low detected\n},
   'info message - battery low');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','2003f3831e') }),
   q{RFXSensor error rfsensor03f3: }.
     qq{1-wire device connected is not a DS18B20 or DS2438\n},
   'error message - unsupported 1-wire device');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','2003f39917') }),
   qq{RFXSensor unknown status messages: 99\n},
   'unknown status message');

