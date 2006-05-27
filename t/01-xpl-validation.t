#!/usr/bin/perl -w
#
# Copyright (C) 2005 by Mark Hindess

use strict;
use Test::More tests => 107;
use t::Helpers qw/test_error test_warn/;

use_ok('xPL::Validation');

is(test_error(sub { xPL::Validation->new(); }),
   q{xPL::Validation->new: requires 'type' parameter},
   'xPL::Validation requires type parameter');

my $validation = xPL::Validation->new(type => "Any");
ok($validation, '"Any" validation');
is((ref $validation), "xPL::Validation::Any", '"Any" validation ref');
is($validation->type, "Any", '"Any" validation type');
is($validation->summary(), "Any", '"Any" validation summary');
is($validation->error(), 'It can be any value.', '"Any" validation "error"');

ok($validation->valid('xxx'), '"Any" validation accepts "xxx"');
ok($validation->valid(), '"Any" validation accepts undef');

$validation = xPL::Validation->new(type => "Integer");
ok($validation, '"Integer" validation');
is((ref $validation), "xPL::Validation::Integer", '"Integer" validation ref');
is($validation->type, "Integer", '"Integer" validation type');
is($validation->summary(), "Integer", '"Integer" validation summary');
is($validation->error(), 'It should be an integer.',
   '"Integer" validation "error"');

ok($validation->valid(10), '"Integer" validation accepts "10"');
ok($validation->valid(-10), '"Integer" validation accepts "-10"');
ok(!$validation->valid(10.3), '"Integer" validation forbids "10.3"');
ok(!$validation->valid('xxx'), '"Integer" validation forbids "xxx"');
ok(!$validation->valid(undef), '"Integer" validation forbids undef');

$validation = xPL::Validation->new(type => "PositiveInteger");
ok($validation, '"PositiveInteger" validation');
is((ref $validation), "xPL::Validation::PositiveInteger",
   '"PositiveInteger" validation ref');
is($validation->type, "PositiveInteger", '"PositiveInteger" validation type');
is($validation->summary(), "PositiveInteger",
   '"PositiveInteger" validation summary');
is($validation->error(), 'It should be a positive integer.',
   '"PositiveInteger" validation "error"');

ok($validation->valid(10), '"PositiveInteger" validation accepts "10"');
ok(!$validation->valid(0), '"PositiveInteger" validation forbids "0"');
ok(!$validation->valid(-10), '"PositiveInteger" validation forbids "-10"');
ok(!$validation->valid('xxx'), '"PositiveInteger" validation forbids "xxx"');
ok(!$validation->valid(undef), '"PositiveInteger" validation forbids undef');

$validation = xPL::Validation->new(type => "IntegerRange");
ok($validation, '"IntegerRange" validation');
is((ref $validation), "xPL::Validation::IntegerRange",
   '"IntegerRange" validation ref');
is($validation->type, "IntegerRange", '"IntegerRange" validation type');
is($validation->summary(), "IntegerRange min=none max=none",
   '"IntegerRange" validation summary');
is($validation->error(), 'It should be an integer.',
   '"IntegerRange" validation "error"');

ok($validation->valid(10), '"IntegerRange" validation accepts "10"');
ok($validation->valid(-10), '"IntegerRange" validation accepts "-10"');
ok(!$validation->valid('xxx'), '"IntegerRange" validation forbids "xxx"');
ok(!$validation->valid(undef), '"IntegerRange" validation forbids undef');

$validation = xPL::Validation->new(type => "IntegerRange",
                                   min => 5);
ok($validation, '"IntegerRange min=5" validation');
is((ref $validation), "xPL::Validation::IntegerRange",
   '"IntegerRange min=5" validation ref');
is($validation->type, "IntegerRange", '"IntegerRange min=5" validation type');
is($validation->summary(), "IntegerRange min=5 max=none",
   '"IntegerRange min=5" validation summary');
is($validation->error(), 'It should be an integer greater than or equal to 5.',
   '"IntegerRange min=5" validation "error"');

ok($validation->valid(10), '"IntegerRange min=5" validation accepts "10"');
ok(!$validation->valid(-10), '"IntegerRange min=5" validation forbids "-10"');
ok(!$validation->valid('xxx'),
   '"IntegerRange min=5" validation forbids "xxx"');
ok(!$validation->valid(undef),
   '"IntegerRange min=5" validation forbids undef');

$validation = xPL::Validation->new(type => "IntegerRange",
                                   max => 5);
ok($validation, '"IntegerRange max=5" validation');
is((ref $validation), "xPL::Validation::IntegerRange",
   '"IntegerRange max=5" validation ref');
is($validation->type, "IntegerRange", '"IntegerRange max=5" validation type');
is($validation->summary(), "IntegerRange min=none max=5",
   '"IntegerRange max=5" validation summary');
is($validation->error(), 'It should be an integer less than or equal to 5.',
   '"IntegerRange max=5" validation "error"');

ok(!$validation->valid(10), '"IntegerRange max=5" validation forbids "10"');
ok($validation->valid(-10), '"IntegerRange max=5" validation accepts "-10"');
ok(!$validation->valid('xxx'),
   '"IntegerRange max=5" validation forbids "xxx"');
ok(!$validation->valid(undef),
   '"IntegerRange max=5" validation forbids undef');

$validation = xPL::Validation->new(type => "IntegerRange",
                                   min => -10, max => 10);
ok($validation, '"IntegerRange min=-10 max=10" validation');
is((ref $validation), "xPL::Validation::IntegerRange",
   '"IntegerRange min=-10 max=10" validation ref');
is($validation->type, "IntegerRange",
   '"IntegerRange min=-10 max=10" validation type');
is($validation->summary(), "IntegerRange min=-10 max=10",
   '"IntegerRange min=-10 max=10" validation summary');
is($validation->error(), 'It should be an integer between -10 and 10.',
   '"IntegerRange min=-10 max=10" validation "error"');

ok($validation->valid(10),
   '"IntegerRange min=-10 max=10" validation accepts "10"');
ok($validation->valid(0),
   '"IntegerRange min=-10 max=10" validation accepts "0"');
ok($validation->valid(-10),
   '"IntegerRange min=-10 max=10" validation accepts "-10"');
ok(!$validation->valid(-11),
   '"IntegerRange min=-10 max=10" validation forbids "-11"');
ok(!$validation->valid(11),
   '"IntegerRange min=-10 max=10" validation forbids "11"');
ok(!$validation->valid('xxx'),
   '"IntegerRange min=-10 max=10" validation forbids "xxx"');
ok(!$validation->valid(undef),
   '"IntegerRange min=-10 max=10" validation forbids undef');


$validation = xPL::Validation->new(type => "Pattern", pattern => '[a-z]');
ok($validation, '"IntegerRange pattern=[a-z]" validation');
is((ref $validation), "xPL::Validation::Pattern",
   '"Pattern pattern=[a-z]" validation ref');
is($validation->type, "Pattern",
   '"Pattern pattern=[a-z]" validation type');
is($validation->summary(), "Pattern pattern=[a-z]",
   '"Pattern pattern=[a-z]" validation summary');
is($validation->error(), 'It should match the pattern "[a-z]".',
   '"Pattern pattern=[a-z]" validation "error"');

ok($validation->valid("a"),
   '"Pattern pattern=[a-z]" validation accepts "a"');
ok(!$validation->valid("0"),
   '"Pattern pattern=[a-z]" validation forbids "0"');
ok(!$validation->valid(""),
   '"Pattern pattern=[a-z]" validation forbids ""');
ok(!$validation->valid(undef),
   '"Pattern pattern=[a-z]" validation forbids undef');

is(test_error(sub { xPL::Validation->new(type => "Pattern"); }),
   q{xPL::Validation::Pattern->init: requires 'pattern' parameter},
   'Pattern requires pattern parameter');


$validation = xPL::Validation->new(type => "IP");
ok($validation, '"IP" validation');
is((ref $validation), "xPL::Validation::IP",'"IP" validation ref');
is($validation->type, "IP",'"IP" validation type');
is($validation->summary(), "IP", '"IP" validation summary');
is($validation->error(), 'It should be an IP address.',
   '"IP" validation "error"');

ok($validation->valid("127.0.0.1"), '"IP" validation accepts "127.0.0.1"');
ok(!$validation->valid("127.1"), '"IP" validation forbids "127.1"');
ok(!$validation->valid("256.0.0.1"), '"IP" validation forbids "256.0.0.1"');
ok(!$validation->valid(undef), '"IP" validation forbids undef');


$validation = xPL::Validation->new(type => "Set", set => [qw/a b c/]);
ok($validation, '"Set" validation');
is((ref $validation), "xPL::Validation::Set",'"Set" validation ref');
is($validation->type, "Set",'"Set" validation type');
is($validation->summary(), "Set set='a', 'b' or 'c'",
   '"Set" validation summary');
is($validation->error(), q{It should be one of 'a', 'b' or 'c'.},
   '"Set" validation "error"');

ok($validation->valid("a"), '"Set" validation accepts "a"');
ok($validation->valid("b"), '"Set" validation accepts "b"');
ok($validation->valid("c"), '"Set" validation accepts "c"');
ok(!$validation->valid("d"), '"Set" validation forbids "d"');
ok(!$validation->valid(undef), '"Set" validation forbids undef');

$validation = xPL::Validation->new(type => "Set", set => ['a'..'z']);
is($validation->summary(), "Set set='a', 'b', 'c', 'd', 'e', 'f', 'g', 'h...",
   '"Set" validation summary');

is(test_error(sub { xPL::Validation->new(type => "Set"); }),
   q{xPL::Validation::Set->init: requires 'set' parameter},
   'Set requires set parameter');

is(test_warn(sub { $validation=xPL::Validation->new(type => "Red"); }),
   undef, 'Unknown validation created no warnings');
ok($validation, 'Unknown validation');
is((ref $validation), "xPL::Validation::Any", 'Unknown validation ref');
is($validation->type, 'Red', 'Unknown validation type');
is($validation->summary(), 'Red', 'Unknown validation summary');
is($validation->error(), q{It can be any value.},
   'Unknown validation "error"');

$ENV{XPL_VALIDATION_WARN} = 1;
is(test_warn(sub { $validation=xPL::Validation->new(type => "Green",
                                                    verbose => 1); }),
   q{Failed to load xPL::Validation::Green: }.
     q{Can't locate xPL/Validation/Green.pm in @INC},
   'Unknown validation created with warnings');
ok($validation, 'Unknown validation with warnings');
delete $ENV{XPL_VALIDATION_WARN};
