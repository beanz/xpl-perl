#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 2;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock');

is(test_error(sub { xPL::Dock->import('invalid') }),
   q{Failed loading plugin: Can't locate xPL/Dock/invalid.pm in @INC},
   'plugin eval error');
