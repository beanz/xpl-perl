#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
use Test::More tests => 4;
use t::Helpers qw/:all/;

is(test_error(sub { die 'argh' }),
   'argh',
   'died horribly');

is(test_warn(sub { warn 'danger will robinson' }),
   'danger will robinson',
   'warned nicely');

is(test_output(sub { print "stdout"; }, \*STDOUT),
   'stdout', 'catching stdout');
is(test_output(sub { print STDERR "stderr"; }, \*STDERR),
   'stderr', 'catching stderr');

