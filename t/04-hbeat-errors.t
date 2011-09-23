#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Test::More tests => 8;
use t::Helpers qw/test_error test_warn/;

BEGIN {
  $ENV{XPL_MESSAGE_VALIDATE} = 1;
}

use_ok("xPL::Message");

my $msg;
is(test_error(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                       ); }),
   "xPL::ValidatedMessage::hbeat::app::xplstat->process_field_record: requires 'port' parameter in body",
   "xPL::Message::hbeat::app missing port test");

is(test_error(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => [ port => 12345, ],
                       ); }),
   "xPL::ValidatedMessage::hbeat::app::xplstat->process_field_record: requires 'remote_ip' parameter in body",
   "xPL::Message::hbeat::app missing remote_ip test");

is(test_error(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => [ port => 123, ],
                       ); }),
   "xPL::ValidatedMessage::hbeat::app::xplstat->port: port, 123, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number too low");

is(test_error(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => [ port => 99999, ],
                       ); }),
   "xPL::ValidatedMessage::hbeat::app::xplstat->port: port, 99999, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number too high");

is(test_error(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => [ port => 'notvalid', ],
                       ); }),
   "xPL::ValidatedMessage::hbeat::app::xplstat->port: port, notvalid, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number invalid");

# Check that invalid port number is accepted if strict mode is off.
my $port;
is(test_warn(sub {
                $msg = xPL::Message->new(
                         message_type => 'xpl-stat',
                         schema => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         strict => 0,
                         body => [ port => 123, ],
                       );
                $port = $msg->port();
              }),
   'xPL::ValidatedMessage::hbeat::app::xplstat->process_field_record: requires '.
     '\'remote_ip\' parameter in body',
   "xPL::Message::hbeat::app port number too low - not strict");
is($port, 123,
   "xPL::Message::hbeat::app port number too low - not strict value");
