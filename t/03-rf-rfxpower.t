#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 14;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*','3000f00006000a');
is($res->{length}, 7, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rfxpower.00[energy]=15.36},
   'returns correct message');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','3000f00006000b');
             }),
   "RFXPower parity error 10 != 11\n",
   'rfxcom parity error');
is($res->{length}, 7, 'recognizes sufficient data');
is(scalar @{$res->{messages}}, 0, 'array has no messages');

is(test_warn(sub {
               $res = $rf->process_variable_length(pack 'H*','3000f0000600fa');
             }),
   "Unsupported rfxpower message identification packet\nH:: 00f0000600fa\n",
   'rfxcom parity error');
is($res->{length}, 7, 'recognizes sufficient data');
is(scalar @{$res->{messages}}, 0, 'array has no messages');

$res = $rf->process_variable_length(pack 'H*','3000f000000000');
is($res->{length}, 7, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rfxpower.00[energy]=0},
   'returns correct message');

$res = $rf->process_variable_length(pack 'H*','30000000000000');
is($res->{length}, 7, 'processing recognizes sufficient data');
is(scalar @{$res->{messages}}, 0, 'processing array has no messages');
