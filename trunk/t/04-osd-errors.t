#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Test::More tests => 2;
use t::Helpers qw/test_error/;

use_ok("xPL::Message");

my $msg;
is(test_error(sub {
                $msg = xPL::Message->new(class => "osd.basic",
                         head => { source => "vendor-device.instance" },
                       ); }),
   "xPL::Message::osd::basic::xplcmnd->process_field_record: requires 'command' parameter in body",
   "xPL::Message::osd::basic missing command test");
