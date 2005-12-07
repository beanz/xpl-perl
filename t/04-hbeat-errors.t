#!/usr/bin/perl -w
use strict;
use Test::More tests => 7;
use t::Helpers qw/test_error/;

use_ok("xPL::Message");

my $msg;
is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                       ); }),
   "xPL::Message::hbeat::app->process_field_record: requires 'port' parameter in body",
   "xPL::Message::hbeat::app missing port test");

is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => { port => 12345, },
                       ); }),
   "xPL::Message::hbeat::app->process_field_record: requires 'remote_ip' parameter in body",
   "xPL::Message::hbeat::app missing remote_ip test");

is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => { port => 123, },
                       ); }),
   "xPL::Message::hbeat::app->port: port, 123, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number too low");

is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => { port => 99999, },
                       ); }),
   "xPL::Message::hbeat::app->port: port, 99999, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number too high");

is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         body => { port => 'notvalid', },
                       ); }),
   "xPL::Message::hbeat::app->port: port, notvalid, is invalid.
It should be an integer between 1024 and 65535.",
   "xPL::Message::hbeat::app port number invalid");

# Check that invalid port number is accepted if strict mode is off.
is(test_error(sub {
                $msg = xPL::Message->new(class => "hbeat.app",
                         head => {source => "vendor-device.instance"},
                         strict => 0,
                         body => { port => 123, },
                       ); }),
   "xPL::Message::hbeat::app->process_field_record: requires 'remote_ip' parameter in body",
   "xPL::Message::hbeat::app port number too low - not strict");
