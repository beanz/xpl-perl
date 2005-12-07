#!/usr/bin/perl -w
use strict;
use Test::More tests => 2;

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
is($str, $payload, "payload test");
