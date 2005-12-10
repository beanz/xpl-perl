#!/usr/bin/perl -w
use strict;
use Test::More tests => 3;

use_ok("xPL::Message");

my $msg;
my $payload =
"xpl-stat
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
";

my $str = xPL::Message->new_from_payload($payload)->string;
is($str, $payload, "new_from_payload");

my $payload_pre =
"xpl-stat
{
hop=1
source=vendor-device-instance
target=*
}
fred.schema
{
";
my $payload_body =
"b=value-b
c=value-c
a=value-a
b=value-b2
}
";

$payload = $payload_pre.$payload_body;

$str = xPL::Message->new_from_payload($payload)->string;
# order means 'b' still comes first but the second value overrides the
# first leaving
$payload_body =
"b=value-b2
c=value-c
a=value-a
}
";
$payload = $payload_pre.$payload_body;
is($str, $payload, "new_from_payload with duplicate field");
