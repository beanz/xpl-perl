#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2006 by Mark Hindess

use strict;
use Test::More tests => 33;
use t::Helpers qw/test_error test_warn/;
$|=1;

use_ok('xPL::Listener');

my $xpl = xPL::Listener->new(ip => '127.0.0.1',
                             broadcast => '127.255.255.255',
                            );
ok($xpl, 'test xpl listener object create');

# test some of the errors caused by mis-use of the 'internal'
# collection api

is(test_error(sub { $xpl->make_collection_method(); }),
   "xPL::Listener->make_collection_method: BUG: missing collection type",
   'error message on making collection method without type');

is(test_error(sub { $xpl->make_collection_method('foo'); }),
   "xPL::Listener->make_collection_method: BUG: missing method template",
   'error message on making collection method without method template');

is(test_error(sub { $xpl->make_item_attribute_method(); }),
   "xPL::Listener->make_item_attribute_method: BUG: missing collection type",
   'error message on making item attribute method without type');
is(test_error(sub { $xpl->make_item_attribute_method('foo'); }),
   "xPL::Listener->make_item_attribute_method: BUG: missing attribute name",
   'error message on making item attribute method without attribute name');

foreach my $method (qw/add_item remove_item
                       items item_attrib exists_item/) {
  is(test_error(sub { $xpl->$method(); }),
     "xPL::Listener->$method: BUG: item type missing",
     'error message on incorrect api use: '.$method.' 1');

  is(test_error(sub { $xpl->$method('splat'); }),
     "xPL::Listener->$method: BUG: item type, splat, invalid",
     'error message on incorrect api use: '.$method.' 2');

  next if ($method eq 'items');

  is(test_error(sub { $xpl->$method('timer'); }),
     "xPL::Listener->$method: BUG: item id missing",
     'error message on incorrect api use: '.$method.' 3');
}

is(test_error(sub { $xpl->init_items(); }),
   'xPL::Listener->init_items: BUG: item type missing',
   'error message on incorrect api use: init collections 1');

is(test_error(sub { $xpl->init_items('timer'); }),
 'xPL::Listener->init_items: BUG: item type, timer, already initialized',
 'error message on initializing already existing collection');

is(test_error(sub { $xpl->add_item('timer'); }),
   'xPL::Listener->add_item: BUG: item id missing',
   'error message on adding item without an id');

is(test_error(sub { $xpl->add_item('timer', 'pling'); }),
   'xPL::Listener->add_item: BUG: item attribs missing',
   'error message on adding item without attributes');

is(test_warn(sub { $xpl->item_attrib('timer', 'pling', 'key'); }),
   "xPL::Listener->item_attrib: timer item 'pling' not registered",
   'warning message on querying item attribute for non-existent item');

ok($xpl->add_item('timer', 'pling', {}), "adding temporary item for test");

is(test_error(sub { $xpl->item_attrib('timer', 'pling'); }),
   'xPL::Listener->item_attrib: missing key',
   'error message on querying item attribute without attribute name');

is(test_error(sub { $xpl->add_callback_item(); }),
   'xPL::Listener->add_item: BUG: item type missing',
   'error message on invalid call to add_callback_item');

ok(xPL::Listener->make_item_attribute_method('pling', 'springy'),
  "making attribute method");
ok(!xPL::Listener->make_item_attribute_method('pling', 'springy'),
  "not making duplicate attribute method");

{
 package MyTest;
 use xPL::Listener;
 our @ISA = qw/xPL::Listener/;
 sub attrib { return 'accessor not overriden' }
 __PACKAGE__->make_readonly_accessor("attrib");
 sub add_whatsit { return 'collection method not overriden' };
 __PACKAGE__->make_collection(whatsit => [qw/name/]);
}

$xpl = MyTest->new(ip => '127.0.0.1', broadcast => '127.255.255.255');
ok($xpl, 'method maker override test object');
is($xpl->attrib, 'accessor not overriden', 'accessor not overriden');
is($xpl->add_whatsit, 'collection method not overriden',
   'collection method not overriden');
