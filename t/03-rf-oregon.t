#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 6;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res =
  $rf->process_variable_length(pack 'H*','78ea7c10804870ade4fbffafce070188');
is($res->{length}, 16, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - uv138.80[uv]=4},
   'returns correct message');
is($res->{messages}->[0]->extra_field('risk'), 'medium', 'risk field');

$res = $rf->process_variable_length(pack 'H*','50dacc134d312220644e32');
is($res->{length}, 11, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - rtgr328n.4d[temp]=22.3},
   'returns correct message');
