#!/usr/bin/perl -w
#
# Copyright (C) 2009, 2010 by Mark Hindess

use strict;
use Test::More tests => 44;
use File::Temp qw/tempdir/;
use t::Helpers qw/test_error test_warn test_output/;

my $dir = tempdir(CLEANUP => 1);
$ENV{XPL_CONFIG_PATH} = $dir;
push @INC, 't/config';

use_ok('xPL::Config');

my $config = xPL::Config->new(key => 'test', instance => '1');
ok($config, 'object create');

is_deeply([$config->items],
          [qw/newconf username password resource host port friend/],
          'items list');
is($config->number_of_items, 7, 'number of items');
ok($config->is_item('username'), 'is_item(\'username\')');
ok($config->is_item_required('username'), 'is_item_required(\'username\')');
ok(!$config->is_item_required('port'), '!is_item_required(\'port\')');
is($config->max_item_values('username'), 1, 'max_item_values(\'username\')');
is($config->max_item_values('friend'), 32, 'max_item_values(\'friend\')');
is($config->item_type('port'), 'option', 'item_type(\'port\')');
is($config->item_type('username'), 'reconf', 'item_type(\'username\')');
ok(!$config->get_item('username'), '!get_item(\'username\')');
is($config->set_item('username','user'), 'user',
   'set_item(\'username\',\'user\')');
is($config->get_item('username','user'), 'user', 'get_item(\'username\')');
is_deeply([$config->items_requiring_config()],
          [qw/password/], 'items_requiring_config()');
is_deeply($config->config_types,
          [
           reconf => [qw/username password/],
           option => [qw/newconf resource host port friend[32]/],
          ],
          'config_types()');
is_deeply($config->config_current,
          [
           newconf => '',
           username => 'user',
           password => '',
           resource => '',
           host => '',
           port => '',
           friend => '',
          ],
          'config_current()');
ok(!$config->update_item('username','user'),
   'update_item(\'username\',\'user\')');
is($config->update_item('username','a.n.other'),
   'changed',
   'update_item(\'username\',\'a.n.other\')');
is($config->get_item('username'),'a.n.other', 'get_item(\'username\')');

is($config->update_item('password','passw0rd'),
   'set',
   'update_item(\'password\',\'passw0rd\')');
is($config->get_item('password'),'passw0rd', 'get_item(\'password\')');

is($config->update_item('friend',['a','b']),
   'set',
   'update_item(\'friend\',[\'a\',\'b\'])');
is_deeply($config->get_item('friend'),
          [qw/a b/], 'get_item(\'friend\')');
ok(!$config->update_item('friend',['a','b']),
   '!update_item(\'friend\',[\'a\',\'b\'])');
is($config->update_item('friend',['a','b','c']),
   'changed',
   'update_item(\'friend\',[\'a\',\'b\',\'c\'])');
is_deeply($config->get_item('friend'),
          [qw/a b c/], 'get_item(\'friend\')');

is($config->update_item('friend',['a','b','d']),
   'changed',
   'update_item(\'friend\',[\'a\',\'b\',\'d\'])');
is_deeply($config->get_item('friend'),
          [qw/a b d/], 'get_item(\'friend\')');

is($config->update_item('friend','one'),
   'changed',
   'update_item(\'friend\',\'one\')');
is_deeply($config->get_item('friend'),
          [qw/one/], 'get_item(\'friend\')');

is($config->set_item('friend','two'),
   'two',
   'set_item(\'friend\',\'two\')');
is_deeply($config->get_item('friend'),
          [qw/two/], 'get_item(\'friend\')');

ok(!$config->update_item('notitem'), 'update_item(\'notitem\')');

$config = xPL::Config->new(key => 'test2', instance => '1');
ok($config, 'object create');

is_deeply([$config->items],
          [qw/newconf username password resource host port friend/],
          'items list');

is_deeply($config->config_types,
          [
           reconf => [qw/username password/],
           option => [qw/newconf resource host port friend[32]/],
          ],
          'config_types()');

ok(!xPL::Config->new(key => 'noconfig'), 'key => \'noconfig\'');

is(test_error(sub { xPL::Config->new(key => 'test3') }),
   ("Config spec in, t/config/xPL/config/test3.yaml,\n".
    "must contain a hash ref with items array ref"),
   'no spec');

is(test_error(sub { xPL::Config->new(key => 'test4') }),
   ("Config spec in, t/config/xPL/config/test4.yaml,\n".
    "must contain a hash ref with items array ref"),
   'not hash');

is(test_error(sub { xPL::Config->new(key => 'test5') }),
   ("Config spec in, t/config/xPL/config/test5.yaml,\n".
    "must contain a hash ref with items array ref"),
   'no items');

is(test_error(sub { xPL::Config->new(key => 'test6') }),
   ("Config spec in, t/config/xPL/config/test6.yaml,\n".
    "must contain a hash ref with items array ref"),
   'items not list');

like(test_error(sub { xPL::Config->new(key => 'invalid', instance => '1') }),
     qr/^Failed to read config spec from t/,
     'invalid spec');

delete $ENV{XPL_CONFIG_PATH};
like(test_error(sub { xPL::Config->new(key => 'test', instance => '1') }),
     qr!^Failed to create configuration DB_File!, 'no config dir');
