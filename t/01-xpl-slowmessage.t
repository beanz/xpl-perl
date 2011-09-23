#!/usr/bin/perl -w
#
# Copyright (C) 2007, 2008 by Mark Hindess

use strict;
use Test::More tests => 15;
use Data::Dumper;
use t::Helpers qw/test_warn test_error/;
no warnings qw/deprecated/;

$ENV{XPL_MESSAGE_VALIDATE} = 1;

use_ok('xPL::Message');

my $msg;

ok($msg = xPL::Message->new(message_type => "xpl-stat",
                            schema => "fred.schema",
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
is($msg->strict, 0, 'testing getter - strict');
is($msg->strict(1), 1, 'testing setter - strict');
is($msg->hop, '1', 'testing getter - hop');
is($msg->source, 'source', 'testing getter - source');
is($msg->target, '*', 'testing getter - target');
is((join ',', $msg->extra_fields()), 'field1,field2', 'testing extra_fields');
is($msg->extra_field_string(),
   "field1=value1\nfield2=value2\n", 'testing extra_field_string');
my $payload = $msg->string;
ok($msg = xPL::Message->new_from_payload($payload),'new from payload');
is((join ',', $msg->extra_fields()), 'field1,field2', 'testing extra_fields');
ok($msg = xPL::Message->new_from_payload($payload),'new from payload');
is($msg->extra_field_string(),
   "field1=value1\nfield2=value2\n", 'testing extra_field_string');

# regression test for http://www.xpl-perl.org.uk/ticket/24
# xPL::Message->new(...) corrupts the body argument
my %args = (message_type => 'xpl-cmnd',
            schema => 'x10.basic',
            head => { source => 'bnz-acme.test' },
            body => {
                     command => 'on',
                     device => 'a1',
                     extra => 'test',
                    }
           );
my $before = Data::Dumper->Dump([\%args], [qw/args/]);
ok(xPL::Message->new(%args), 'creating message to check corruption');
my $after = Data::Dumper->Dump([\%args], [qw/args/]);
is($after, $before, 'checking for corruption');

