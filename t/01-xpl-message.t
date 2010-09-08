#!/usr/bin/perl -w
#
# Copyright (C) 2007, 2010 by Mark Hindess

use strict;
use Test::More tests => 12;
use Data::Dumper;
use t::Helpers qw/test_warn test_error/;

use_ok('xPL::Message');

my $msg;

ok($msg = xPL::Message->new(message_type => "xpl-stat",
                            schema => "fred.schema",
                            head =>
                            {
                             source => 'bnz-acme.source',
                            },
                            body =>
                            [
                             field1 => 'value1',
                             field2 => 'value2',
                            ],
                           ), 'new message');
is($msg->hop, '1', 'testing getter - hop');
is($msg->source, 'bnz-acme.source', 'testing getter - source');
is($msg->target, '*', 'testing getter - target');
is((join ',', $msg->body_fields()), 'field1,field2', 'testing body_fields');
is($msg->body_string(),
   "fred.schema\n{\nfield1=value1\nfield2=value2\n}\n",
   'testing body_string');
my $payload = $msg->string;
ok($msg = xPL::Message->new_from_payload($payload),'new from payload');
is((join ',', $msg->body_fields()), 'field1,field2', 'testing body_fields');
is($msg->body_string(),
   "fred.schema\n{\nfield1=value1\nfield2=value2\n}\n", 'testing body_string');

# regression test for http://www.xpl-perl.org.uk/ticket/24
# xPL::Message->new(...) corrupts the body argument
my %args = (message_type => 'xpl-cmnd',
            schema => 'x10.basic',
            head => { source => 'bnz-acme.test' },
            body => [
                     command => 'on',
                     device => 'a1',
                     extra => 'test',
                    ]
           );
my $before = Data::Dumper->Dump([\%args], [qw/args/]);
ok(xPL::Message->new(%args), 'creating message to check corruption');
my $after = Data::Dumper->Dump([\%args], [qw/args/]);
is($after, $before, 'checking for corruption');
