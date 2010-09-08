#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2010 by Mark Hindess

use strict;
use Test::More tests => 16;
use t::Helpers qw/test_warn test_error/;

use_ok("xPL::Message");
my $valid_msg = xPL::Message->new(message_type => 'xpl-cmnd',
                                  head => { source => 'acme-test.test' },
                                  class => 'test.schema');
ok($valid_msg, 'sample message to get message type');
my $ref = ref $valid_msg;
my $msg;
is(test_error(sub { $msg = xPL::Message->new(); }),
   $ref."->new: requires 'class' parameter",
   "xPL::Message missing class test");

is(test_error(sub { $msg = xPL::Message->new(class => "remote.basic") }),
   $ref."->new: requires 'message_type' parameter",
   "xPL::Message missing message type test");

is(test_error(sub { $msg = xPL::Message->new(class => "unknown.basic") }),
   $ref."->new: requires 'message_type' parameter",
   "xPL::Message missing message type test");

is(test_error(sub { $msg = xPL::Message->new(class => "fred.schema",
                                             message_type => 'testing') }),
   ($ref eq 'xPL::Message'
    ? 'xPL::Message->new' : 'xPL::SlowMessage->message_type').
   ": message type identifier, testing, is invalid.
It should be one of xpl-cmnd, xpl-stat or xpl-trig.",
   "xPL::Message invalid message type test");

is(test_error(sub { $msg = xPL::Message->new(message_type => "xpl-stat",
                                             class => "fred.schema"); }),
   $ref."->parse_head_parameters: requires 'source' parameter",
   "xPL::Message missing source test");

my $payload =
"xpl-stat
{
hop=1
source=vendor-device-instance
target=*
}
fred.schema
{
param1=value1
}
";

my $str = xPL::Message->new_from_payload($payload)->string;
is($str, $payload, "payload test");

is(test_warn(sub { $msg =
                     xPL::Message->new_from_payload($payload.
                                                    "some-trailing-junk"); }),
   "xPL::Message->new_from_payload: Trailing trash: some-trailing-junk",
   "trailing junk warning");

chomp($payload);
is(test_warn(sub { $msg = xPL::Message->new_from_payload($payload); }),
   "xPL::Message->new_from_payload: Message badly terminated: ".
     "missing final eol char?",
   "missing eol warning");

$payload =
"xpl-stat
hop=1
source=vendor-device-instance
target=*
}
fred.schema
{
param1=value1
}
";
is(test_error(sub { $msg = xPL::Message->new_from_payload($payload); }),
   "xPL::Message->new_from_payload: Invalid header: xpl-stat
hop=1
source=vendor-device-instance
target=*",
   "badly formatted head");

$payload =
"xpl-stat
{
hop=1
source=vendor-device-instance
target=*
}
fred.schema
param1=value1
}
";
is(test_error(sub { $msg = xPL::Message->new_from_payload($payload); }),
   "xPL::Message->new_from_payload: Invalid body: fred.schema
param1=value1",
   "badly formatted body");

is(test_error(sub { $msg = xPL::Message->new_from_payload(""); }),
   'xPL::Message->new_from_payload: Message badly formed: empty?',
   'empty message passed to new_from_payload');

$msg = xPL::Message->new(message_type => "xpl-stat",
                         head =>
                         {
                          source => "vendor-device.instance",
                         },
                         class => "fred.schema",
                         );

my $invalid;
is(test_error(sub {
  $invalid = xPL::Message->new(message_type => 'xpl-cmnd',
                               class => 'invalid.header',
                               strict => 1,
                               head_content => "hop=10\ntarget=*",
                               body_content => "");
}),
  '',
  'check no error with lazy parsing of head and body');

my $class;
is(test_error(sub { $class = $invalid->class; }),
  q{},
  'check no error when head is parsed - can check class');
is($class, 'invalid.header',
  'check no error when head is parsed - can check class - content');
