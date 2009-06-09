#!/usr/bin/perl -w
#
# Copyright (C) 2008 by Mark Hindess

use strict;
use DirHandle;
use English qw/-no_match_vars/;
use t::Helpers qw/test_warn test_error/;
use Test::More tests => 17;

use_ok('xPL::HomeEasy');

my $rf = xPL::HomeEasy::to_rf(command => 'on',
                              address => 'helloworld',
                              unit => 10) or die;
my $str = unpack "H*", pack("C*", $rf->[0], @{$rf->[1]});
is($str, '21c7e05dda00', 'to_rf - on helloworld[10]');

my $msg = xPL::HomeEasy::from_rf(34,[unpack "C*", pack "H*","c7e05dda00"]);
is((join ",", sort keys %$msg), 'address,command,unit', 'from_rf msg fields');
is($msg->{address}, '52396407', 'from_rf address value');
is($msg->{command}, 'on', 'from_rf command value');
is($msg->{unit}, '10', 'from_rf unit value');

$rf = xPL::HomeEasy::to_rf(command => 'off',
                           address => '0x31f8177',
                           unit => 'group') or die;
$str = unpack "H*", pack("C*", $rf->[0], @{$rf->[1]});
is($str, '21c7e05de000', 'to_rf - on helloworld[group]');

$msg = xPL::HomeEasy::from_rf(34,[unpack "C*", pack "H*","c7e05de000"]);
is((join ",", sort keys %$msg), 'address,command,unit', 'from_rf msg fields');
is($msg->{address}, '52396407', 'from_rf address value');
is($msg->{command}, 'off', 'from_rf command value');
is($msg->{unit}, 'group', 'from_rf unit value');

$rf = xPL::HomeEasy::to_rf(command => 'preset',
                           address => '0x31f8177',
                           unit => '10',
                           level => 7) or die;
$str = unpack "H*", pack("C*", $rf->[0], @{$rf->[1]});
is($str, '24c7e05dca70', 'to_rf - on helloworld[10] preset level=7');

$msg = xPL::HomeEasy::from_rf(36,[unpack "C*", pack "H*","c7e05dca70"]);
is((join ",", sort keys %$msg), 'address,command,level,unit',
   'from_rf msg fields');
is($msg->{address}, '52396407', 'from_rf address value');
is($msg->{command}, 'preset', 'from_rf command value');
is($msg->{level}, '7', 'from_rf level value');
is($msg->{unit}, '10', 'from_rf unit value');

