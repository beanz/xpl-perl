#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 8;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res =
  $rf->process_variable_length(pack 'H*','78ea00a642000000169bff5f1dc05408');
is($res->{length}, 16, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
  'xpl-trig/sensor.basic: '.
   'bnz-rfxcom.localhost -> * - electrisave.a6[current]=6.6',
   'returns correct message');

# different device type
$res =
  $rf->process_variable_length(pack 'H*','78eb00a642000000169bff5f1dc05408');
is($res->{length}, 16, 'recognizes sufficient data - different device');
is(scalar @{$res->{messages}}, 0, 'array has no messages - different device');

# different device type - second byte difference
$res =
  $rf->process_variable_length(pack 'H*','78eaf0a642000000169bff5f1dc05408');
is($res->{length}, 16, 'recognizes sufficient data - different device 2');
is(scalar @{$res->{messages}}, 0, 'array has no messages - different device 2');
