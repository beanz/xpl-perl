#!/usr/bin/perl -w
#
# Copyright (C) 2005 by Mark Hindess

use strict;
use Test::More tests => 8;
use t::Helpers qw/test_warn test_error/;

use_ok('xPL::Base');

{
  package xPL::Test;
  our @ISA=qw/xPL::Base/;
  __PACKAGE__->make_readonly_accessor(qw/test/);
  sub new {
    my $pkg = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
  }
}

my $test = xPL::Test->new();
ok($test);

ok($test->module_available('strict'), 'module available test already used');
ok(!$test->module_available('sloppy'), 'module not available test');
ok($test->module_available('strict'), 'module available test w/cache');
ok($test->module_available('English'), 'module available test');

is(test_warn(sub { $test->test('argh'); }),
   'xPL::Test->test: called with an argument, but test is readonly',
   'testing writing to readonly method');


is(test_error(sub { xPL::Test->make_readonly_accessor(); }),
   'xPL::Test->make_readonly_accessor: BUG: missing attribute name',
   'error message on making item attribute method without attribute name');
