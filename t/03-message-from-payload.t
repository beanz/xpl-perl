#!/usr/bin/perl -w
use strict;
use Test::More tests => 4;
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

is(test_warn(sub { $str = xPL::Message->new_from_payload($payload)->string; }),
   'xPL::Message->new_from_payload: Repeated body field: b',
   'new_from_payload with duplicate field - error');
$payload_body =
'b=value-b
c=value-c
a=value-a
}
';
$payload = $payload_pre.$payload_body;
is($str, $payload, 'new_from_payload with duplicate field - content');
