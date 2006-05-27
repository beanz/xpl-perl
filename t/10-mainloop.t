#!/usr/bin/perl -w
#
# Copyright (C) 2005 by Mark Hindess

use strict;
use Test::More tests => 7;
$|=1;

use_ok('xPL::Listener');
my $xpl = xPL::Listener->new(interface => 'lo');
ok($xpl, 'created listener');

my $count = 0;
$xpl->add_timer(id => 'count',
                callback => sub {
                  $count++;
                  ok(1, 'timer called - '.$count);
                  exit if ($count == 5);
                  return 1;
                },
                timeout => 0.01);
$xpl->main_loop();
