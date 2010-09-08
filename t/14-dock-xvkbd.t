#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 5;
use Time::HiRes;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','Xvkbd');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--xvkbd-verbose');
  $ENV{PATH} = 't/bin:'.$ENV{PATH};
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock xvkbd client');

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Xvkbd', 'plugin has correct type');

is(test_output(sub {
                 $xpl->dispatch_xpl_message(
                   xPL::Message->new(message_type => 'xpl-cmnd',
                                     head =>
                                     {
                                      source => 'acme-xvkbd.test',
                                     },
                                     class=> 'remote',
                                     class_type => 'basic',
                                     body =>
                                     [
                                      'keys' => 'helloworld',
                                     ])) }, \*STDOUT),
   ("Executing 'xvkbd -text helloworld'\n".
    "executed: t/bin/xvkbd -text helloworld\n"),
   'testing execution');
