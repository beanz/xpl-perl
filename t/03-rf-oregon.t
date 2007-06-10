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

$res = $rf->process_variable_length(pack 'H*','689aec134d033311526072605f43');
is($res->{length}, 14, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
   q{xpl-trig/datetime.basic: bnz-rfxcom.localhost -> * - 20070605211330},
   'returns correct message');

$res = $rf->process_variable_length(pack 'H*','501a2d10a42115702536d0');
is($res->{length}, 11, 'recognizes sufficient data');
is($res->{messages}->[0]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - thgr228n.a4[temp]=15.2},
   'returns correct message');
is($res->{messages}->[1]->summary,
q{xpl-trig/sensor.basic: bnz-rfxcom.localhost -> * - thgr228n.a4[humidity]=57},
   'returns correct message');

$res =
  $rf->process_variable_length(pack 'H*','78ea7c10ffff70ade4fbffafce070188');
is($res->{length}, 16, 'recognizes sufficient data');
is(scalar @{$res->{messages}}, 0, 'not uv message - checksum failed');

$res =
  $rf->process_variable_length(pack 'H*','50dacc1ffff12220644e32');
is($res->{length}, 11, 'recognizes sufficient data');
is(scalar @{$res->{messages}}, 0, 'not rtgr328n message - checksum failed');

$res = $rf->process_variable_length(pack 'H*','689aec134d03ff11526072605f43');
is($res->{length}, 14, 'recognizes sufficient data');
is(scalar @{$res->{messages}}, 0,
   'not rtgr328n/datetime message - checksum failed');
