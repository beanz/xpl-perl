#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use English qw/-no_match_vars/;
use xPL::Base;
use Test::More tests => 71;
use t::Helpers qw/test_error/;
$| = 0;

{
  package xPL::Test;
  our @ISA=qw/xPL::Base/;
  sub new {
    my $pkg = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
  }
}

$ENV{TEST_HARNESS_OVERRIDE} = 1;

# test the parsing by abusing the PATH variable to run some wrappers
foreach my $path (qw{t/interfaces/ifconfig.linux
                     t/interfaces/ip.addr.show.linux}) {
  $ENV{PATH} = $path;
  my $test = xPL::Test->new();
  ok($test, "test object - $path");
  my $src = -f $path.'/ifconfig' ? 'ifconfig' : 'ip';
  my $list = $test->interfaces();
  ok($list, "interfaces - $path");
  is(@$list, 3, "interfaces length - $path");
  is($list->[0]->{device}, 'eth0', "interfaces device - $path");
  is($list->[0]->{src}, $src, "interfaces src - $path");
  is($list->[0]->{ip}, '192.168.3.13', "interfaces ip - $path");
  is($list->[0]->{broadcast}, '192.168.3.255', "interfaces broadcast - $path");

  # hack the cache because we didn't use the API properly
  $test->{_interfaces} = $list;

  is($test->interface_ip('eth0'), '192.168.3.13',
     "interface ip eth0 - $path");
  is($test->interface_broadcast('eth0'), '192.168.3.255',
     "interface broadcast eth0 - $path");

  is($test->interface_ip('lo'), '127.0.0.1',
     "interface ip lo - $path");
  is($test->interface_broadcast('lo'), '127.0.0.1',
     "interface broadcast lo - $path");
}

foreach my $path (qw{t/interfaces/ifconfig.macosx}) {
  $ENV{PATH} = $path;
  my $test = xPL::Test->new();
  ok($test, "test object - $path");
  my $src = -f $path.'/ifconfig' ? 'ifconfig' : 'ip';
  my $list = $test->interfaces();
  ok($list, "interfaces - $path");
  is(@$list, 2, "interfaces length - $path");
  is($list->[0]->{device}, 'lo0', "interfaces device - $path");
  is($list->[0]->{src}, $src, "interfaces src - $path");
  is($list->[0]->{ip}, '127.0.0.1', "interfaces ip - $path");
  is($list->[0]->{broadcast}, '127.0.0.1',"interfaces broadcast - $path");

  # hack the cache because we didn't use the API properly
  $test->{_interfaces} = $list;

  is($test->interface_ip('en0'), '192.168.3.13',
     "interface ip en0 - $path");
  is($test->interface_broadcast('en0'), '192.168.3.255',
     "interface broadcast en0 - $path");

  is($test->interface_ip('lo0'), '127.0.0.1',
     "interface ip lo0 - $path");
  is($test->interface_broadcast('lo0'), '127.0.0.1',
     "interface broadcast lo0 - $path");

  is($test->interface_ip('lo'), '127.0.0.1',
     "interface ip lo - $path");
  is($test->interface_broadcast('lo'), '127.0.0.1',
     "interface broadcast lo - $path");
}


$ENV{PATH} = 't/interfaces/ifconfig.empty';
my $test = xPL::Test->new();
ok($test, "test object - main");
my $list = $test->interfaces();
ok($list, "interfaces - empty");
is(@$list, 0, "interfaces length - empty");

$ENV{PATH} = 't/interfaces/ifconfig.macosx';
$test = xPL::Test->new();
ok($test, "test object - main");
my $info = $test->default_interface_info();
ok($info, "default interface");
is($info->{device}, 'en0', 'default interface device');
is($info->{src}, 'ifconfig', 'default interface src');
is($info->{ip}, '192.168.3.13', 'default interface ip');
is($info->{broadcast}, '192.168.3.255', 'default interface broadcast');

# finally test the higher level methods with one of the paths
$ENV{PATH} = 't/interfaces/ifconfig.linux';
$test = xPL::Test->new();
ok($test, "test object - main");
$info = $test->default_interface_info();
ok($info, "default interface");
is($info->{device}, 'eth0', 'default interface device');
is($info->{src}, 'ifconfig', 'default interface src');
is($info->{ip}, '192.168.3.13', 'default interface ip');
is($info->{broadcast}, '192.168.3.255', 'default interface broadcast');

$info = $test->interface_info('vmnet8');
ok($info, 'specific interface');
is($info->{device}, 'vmnet8', 'specific interface device');
is($info->{src}, 'ifconfig', 'specific interface src');
is($info->{ip}, '192.168.165.1', 'specific interface ip');
is($info->{broadcast}, '192.168.165.255', 'specific interface broadcast');

ok(!$test->interface_info('ppp0'), 'non-existent interface');
ok(!$test->interface_ip('ppp0'), 'non-existent interface - ip');
ok(!$test->interface_broadcast('ppp0'), 'non-existent interface - broadcast');

ok($test->is_local_address('127.0.0.1'), 'our_address - loopback');
ok(!$test->is_local_address('127.0.0.2'), 'our_address - failure');

# test a trivial broadcast_from_class usage
is(xPL::Base::broadcast_from_class('10.0.0.1', '32'), '10.0.0.1',
   'broadcast_from_class trivial');

# test a non-trivial broadcast_from_class usage
is(xPL::Base::broadcast_from_class('10.0.0.1', '30'), '10.0.0.3',
   'broadcast_from_class non-trivial');

# let's fake the interfaces list and test the failure case
$test->{_interfaces} =
  [
   { device => 'lo', ip => '127.0.0.1', broadcast => '127.0.0.1',
     src => 'manual hack' },
  ];

ok(!$test->default_interface_info(), "failure case - nothing but loopback");


use_ok('xPL::Listener');
my $path = 't/interfaces/ifconfig.loopback.only';
$ENV{PATH} = $path;
my $xpl = xPL::Listener->new();
ok($xpl, "xPL object - $path");
is($xpl->ip, '127.0.0.1', "xPL ip - $path");
is($xpl->broadcast, '127.0.0.1', "xPL broadcast - $path");

$path = 't/interfaces/failure.case';
$ENV{PATH} = $path;
is(test_error(sub { $xpl = xPL::Listener->new() }),
   'xPL::Listener->new: Unable to determine broadcast address.
An interface or broadcast address should be specified.',
   'xPL broadcast failure');
is(test_error(sub { $xpl = xPL::Listener->new(broadcast=>"127.0.0.1") }),
   'xPL::Listener->new: Unable to determine ip address.
An interface or ip address should be specified.',
   'xPL ip failure');

is(test_error(sub { $xpl = xPL::Listener->new(interface => 'eth0') }),
   'xPL::Listener->new: Unable to detect interface eth0',
   'xPL interface failure');


# finally unset HARNESS_ACTIVE to check that find_in_path also checks /sbin
delete $ENV{TEST_HARNESS_OVERRIDE};
is($xpl->find_in_path("route"), '/sbin/route',
   'find_in_path checks /sbin');
