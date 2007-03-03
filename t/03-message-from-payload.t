#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Test::More tests => 6;
use t::Helpers qw/test_warn/;

use_ok('xPL::Message');

my $msg;
my $payload =
'xpl-stat
{
hop=1
source=vendor-device-instance
target=*
}
fred.schema
{
b=value-b
c=value-c
a=value-a
}
';

my $str = xPL::Message->new_from_payload($payload)->string;
is($str, $payload, 'new_from_payload');

my $payload_pre =
'xpl-stat
{
hop=1
source=vendor-device-instance
target=*
}
fred.schema
{
';
my $payload_body =
'b=value-b
c=value-c
a=value-a
b=value-b2
}
';

$payload = $payload_pre.$payload_body;
my $str_in;
my $str_out;
my $fields;
is(test_warn(sub {
 my $xpl = xPL::Message->new_from_payload($payload);
 $str_in = $xpl->string;
 $fields = join(",", $xpl->extra_fields());
 $str_out = $xpl->string;
 }),
   'xPL::Message->_parse_body: Repeated body field: b',
   'new_from_payload with duplicate field - error');
is($fields, 'b,c,a', 'new_from_payload with duplicate field - fields');
is($str_in, $payload, 'new_from_payload with duplicate field - content in');
$payload_body =
'b=value-b
c=value-c
a=value-a
}
';
$payload = $payload_pre.$payload_body;
is($str_out, $payload, 'new_from_payload with duplicate field - content out');
