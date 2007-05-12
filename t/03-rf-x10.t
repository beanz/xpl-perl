#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 33;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::RF');

is(xPL::RF::hex_dump('ABC'), '414243', 'hex_dump() function test');

is(test_error(sub { xPL::RF->new(); }),
   qq{xPL::RF->new: requires 'source' parameter\n},
   'xPL::RF requires source parameter');

my $rf = xPL::RF->new(source => 'bnz-rfxcom.localhost');
ok($rf, 'RF constructor');

my $res = $rf->process_variable_length(pack 'H*', '4d14');
ok(!defined $res, 'ignores short message - version response');

$res = $rf->process_variable_length(pack 'H*', '2c');
ok(!defined $res, 'ignores short message - 2c response');

$res = $rf->process_variable_length(pack 'H*', '2d');
ok(!defined $res, 'ignores bogus short message - 2d');

$res = $rf->process_variable_length(pack 'H*','00');
ok($res, 'recognizes valid length - 0-bit null');
is($res->{length}, 1, 'recognizes sufficient data - 0-bit null');
is(scalar @{$res->{messages}}, 0, 'array has no messages - 0-bit null');

$rf = xPL::RF->new(source => 'bnz-rfxcom.localhost', verbose => 1);
$res = $rf->process_variable_length(pack 'H*','100000');
ok($res, 'recognizes valid length - 16-bit null');
is($res->{length}, 3, 'recognizes sufficient data - 16-bit null');
is(scalar @{$res->{messages}}, 0, 'array has no messages - 16-bit null');

$res = $rf->process_variable_length(pack 'H*', '20649b');
ok($res, 'recognizes valid length w/insufficent data');
is($res->{length}, 0, 'recognizes insufficient data');

$rf = xPL::RF->new(source => 'bnz-rfxcom.localhost',
                   duplicate_timeout => 1);
ok($rf, 'RF constructor - long duplicate timeout');
$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
is($res->{length}, 5, 'recognizes sufficient data - a11 off');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - off a11},
   'returns correct message - a11 off');

$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
is($res->{length}, 5, 'recognizes sufficient data - a11 off dup');
is(scalar @{$res->{messages}}, 0, 'does not return duplicate - a11 off');

# wait for duplicate entry to expire
select undef, undef, undef, 1.1;
$res = $rf->process_variable_length(pack 'H*', '20649b28d70000');
is($res->{length}, 5, 'recognizes sufficient data - a11 off not dup');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - off a11},
   'returns correct message - a11 off not dup');

$res = $rf->process_variable_length(pack 'H*', '20649b08f7');
is($res->{length}, 5, 'recognizes sufficient data - a11 on');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - on a11},
   'returns correct message - a11 on');

$res = $rf->process_variable_length(pack 'H*', '20649b9867');
is($res->{length}, 5, 'recognizes sufficient data a11 dim');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - dim a11},
   'returns correct message - a11 dim');

$res = $rf->process_variable_length(pack 'H*', '20649b8877');
is($res->{length}, 5, 'recognizes sufficient data - a11 bright');
is($res->{messages}->[0]->summary,
   q{xpl-trig/x10.basic: bnz-rfxcom.localhost -> * - bright a11},
   'returns correct message - a11 bright');

# clear unit code cache and try again
$rf->stash('unit_cache', {});
$rf->{_cache} = {}; # clear duplicate cache to avoid hitting it
is(test_warn(sub { $res = $rf->process_variable_length(pack 'H*', '20649b9867');
                 }),
   "Don't have unit code for: a dim\n",
   'missing unit code warning');
is($res->{length}, 5, 'recognizes sufficient data - missing unit code');
is(scalar @{$res->{messages}}, 0, 'array has no messages - missing unit code');

# a non-x10 message
$res = $rf->process_variable_length(pack 'H*', '2064fb9867');
is($res->{length}, 5, 'recognizes sufficient data - non-x10');
is(scalar @{$res->{messages}}, 0, 'array has no messages - non-x10');
