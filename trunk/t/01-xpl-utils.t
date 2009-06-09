#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 6;
use t::Helpers qw/test_warn test_error/;

use_ok('xPL::Utils',qw/:all/);
is(lo_nibble(0x16), 6, 'low nibble');
is(hi_nibble(0x16), 1, 'high nibble');

my $bytes = [0x10, 0x20, 0x40, 0x81];
is(nibble_sum(3, $bytes), 0x7, 'nibble_sum of three bytes');
is(nibble_sum(3.5, $bytes), 0xf, 'nibble_sum of three and a half bytes');
is(nibble_sum(4, $bytes), 0x10, 'nibble_sum of four bytes');

