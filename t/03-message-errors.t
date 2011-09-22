#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2008 by Mark Hindess

use strict;
use Test::More tests => 28;
use t::Helpers qw/test_warn test_error/;

use_ok("xPL::Message");

my $msg;
is(test_error(sub { $msg = xPL::Message->new(); }),
   "xPL::Message->new: requires 'schema' parameter",
   "xPL::Message missing class test");

is(test_error(sub { $msg = xPL::Message->new(class => "remote.basic") }),
   "xPL::Message->new: requires 'message_type' parameter",
   "xPL::Message missing message type test");

is(test_error(sub { $msg = xPL::Message->new(class => "unknown.basic") }),
   "xPL::Message->new: requires 'message_type' parameter",
   "xPL::Message missing message type test");

is(test_error(sub { $msg = xPL::Message->new(class => 'fred') }),
   "xPL::Message->new: requires 'class_type' parameter",
   "xPL::Message missing class type test");

is(test_error(sub { $msg = xPL::Message->new(class => 'thisistoolong',
                                             class_type => 'test') }),
   "xPL::Message->new: 'class' parameter is invalid.
It must be 8 characters from A-Z, a-z and 0-9.",
   "xPL::Message invalid class test");

is(test_error(sub { $msg = xPL::Message->new(class => 'fred',
                                             class_type => 'thisistoolong') }),
   "xPL::Message->new: 'class_type' parameter is invalid.
It must be 8 characters from A-Z, a-z and 0-9.",
   "xPL::Message invalid class type test");

is(test_error(sub { $msg = xPL::Message->new(class => "fred.schema",
                                             message_type => 'testing') }),
   "xPL::Message->message_type: ".
   "message type identifier, testing, is invalid.
It should be one of xpl-cmnd, xpl-stat or xpl-trig.",
   "xPL::Message invalid message type test");

is(test_error(sub { $msg = xPL::Message->new(message_type => "xpl-stat",
                                             class => "fred.schema"); }),
   "xPL::Message->parse_head_parameters: requires 'source' parameter",
   "xPL::Message missing source test");

is(test_error(sub { $msg = xPL::Message->new(message_type => "xpl-stat",
                                             head =>
                                             {
                                              source => 'source',
                                             },
                                             class => "fred.schema",
                                            ); }),
   "xPL::Message->source: source, source, is invalid.
Invalid format - should be 'vendor-device.instance'.",
   "xPL::Message invalid source format test");

is(test_error(sub { $msg =
                      xPL::Message->new(message_type => "xpl-stat",
                                        head =>
                                        {
                                         source => "vendortoolong-device.id",
                                        },
                                        class => "fred.schema",
                                       ); }),
   "xPL::Message->source: source, vendortoolong-device.id, is invalid.
Invalid vendor id - maximum of 8 chars from A-Z, a-z, and 0-9.",
   "xPL::Message invalid source vendor too long test");

is(test_error(sub { $msg =
                      xPL::Message->new(message_type => "xpl-stat",
                                        head =>
                                        {
                                         source => "vendor-devicetoolong.id",
                                        },
                                        class => "fred.schema",
                                       ); }),
   "xPL::Message->source: source, vendor-devicetoolong.id, is invalid.
Invalid device id - maximum of 8 chars from A-Z, a-z, and 0-9.",
   "xPL::Message invalid source device test");

is(test_error(sub { $msg =
                      xPL::Message->new(message_type => "xpl-stat",
                                        head =>
                                        {
                                         source =>
                                           "vendor-device.thisinstancetoolong",
                                        },
                                        class => "fred.schema",
                                       ); }),
   "xPL::Message->source: ".
   "source, vendor-device.thisinstancetoolong, is invalid.
Invalid instance id - maximum of 16 chars from A-Z, a-z, and 0-9.",
   "xPL::Message invalid source instance test");


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

$ENV{XPL_MSG_WARN}=1;
is(test_warn(sub { $msg = xPL::Message->new(class => "unknown.schema",
                                            head => {
                                              source =>"vendor-device.instance",
                                            },
                                            message_type => 'xpl-cmnd') }),
   'xPL::Message->new: New message type unknown.schema',
   "xPL::Message unknown schema warning");

delete $ENV{XPL_MSG_WARN};

is(test_error(sub { $msg =
                       xPL::Message->new(message_type => "xpl-stat",
                                         head =>
                                         {
                                          source => "vendor-device.instance",
                                          hop => 10,
                                         },
                                         class => "fred.schema",
                                        ); }),
   "xPL::Message->hop: hop count, 10, is invalid.
It should be a value from 1 to 9",
   "invalid hop");

is(test_error(sub { $msg =
                      xPL::Message->new(message_type => "xpl-stat",
                                        head =>
                                        {
                                         source => "vendor-device.instance",
                                         target => 'invalid',
                                        },
                                        class => "fred.schema",
                                       ); }),
   "xPL::Message->target: target, invalid, is invalid.
Invalid format - should be 'vendor-device.instance'.",
   "invalid target");

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

is(test_error(sub { xPL::Message->make_body_field() }),
   'xPL::Message->make_body_field: BUG: missing body field record',
   'make_body_field without field record');

is(test_error(sub { xPL::Message->make_body_field({}) }),
   'xPL::Message->make_body_field: '.
     'BUG: missing body field record missing name',
   'make_body_field with name in field record');

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
is($class, 'invalid',
  'check no error when head is parsed - can check class - content');
my $target;
is(test_error(sub { $target = $invalid->target; }),
  q{xPL::Message->hop: hop count, 10, is invalid.
It should be a value from 1 to 9},
  'check no error when head is parsed - can\'t check target');
