#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use Test::More tests => 3;
BEGIN {
  $ENV{XPL_MESSAGE_VALIDATE} = 1;
  $ENV{XPL_SCHEMA_PATH} = 't/schema';
  package xPL::ValidatedMessage::test::basic::xpltrig;
  sub fieldname {
    return "field not overriden";
  }
  sub body_fields {
    return "body_fields not overriden";
  }
}
use xPL::Message;
use lib 't/lib';
no warnings qw/deprecated/;

my $msg = xPL::Message->new(schema => 'test.basic',
                            head => { source => 'bnz-test.default' });
ok($msg);
is($msg->fieldname, 'field not overriden',
   'field not overriden by automatic methods');
is($msg->body_fields, 'body_fields not overriden',
   'body_fields not overriden by automatic methods');
