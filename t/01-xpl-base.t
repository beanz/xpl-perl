#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
use Test::More tests => 13;
use t::Helpers qw/test_warn test_error test_output/;

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

my @l = xPL::Base::simple_tokenizer("minutes='[10,20,30]'");
is(scalar @l, 2, 'simple_tokenizer - array ref');
is($l[1]->[1], 20, 'simple_tokenizer - array ref element');

is(test_output(sub { $test->info("test") }, \*STDOUT),
   '', 'info method !verbose');
$test->verbose(1);
is(test_output(sub { $test->info("test") }, \*STDOUT),
   'test', 'info method verbose');

is(test_error(sub { $test->call_callback('foo', 'bar') }),
   q{xPL::Test->call_callback: BUG: callback bar of type, foo, doesn't exist},
   'call_callback bug case');
