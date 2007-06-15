#!/usr/bin/perl -w
#
# Copyright (C) 2007 by Mark Hindess

use strict;
use Test::More tests => 10;
use t::Helpers qw/test_warn test_error/;

use_ok('xPL::Message');

my $msg;

ok($msg = xPL::Message->new(message_type => "xpl-stat",
                            class => "fred.schema",
                            head =>
                            {
                             source => 'source',
                            },
                            body =>
                            {
                             field1 => 'value1',
                             field2 => 'value2',
                            },
                            strict => 0,
                           ), 'new message');
is($msg->strict, 0, 'testing setter - strict');
is($msg->strict(1), 1, 'testing getter - strict');
is((join ',', $msg->extra_fields()), 'field1,field2', 'testing extra_fields');
is($msg->extra_field_string(),
   "field1=value1\nfield2=value2\n", 'testing extra_field_string');
my $payload = $msg->string;
ok($msg = xPL::Message->new_from_payload($payload),'new from payload');
is((join ',', $msg->extra_fields()), 'field1,field2', 'testing extra_fields');
ok($msg = xPL::Message->new_from_payload($payload),'new from payload');
is($msg->extra_field_string(),
   "field1=value1\nfield2=value2\n", 'testing extra_field_string');
