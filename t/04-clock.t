#!/usr/bin/perl -w
#
# Copyright (C) 2005 by Mark Hindess

use strict;
use Test::More tests => 3;
use POSIX qw/strftime/;

use_ok("xPL::Message");
my $msg = xPL::Message->new(class => "clock.update",
                            head => { source => "acme-clock.hall", });
ok($msg, "created clock update message");
my $t=strftime("%Y%m%d%H%M", localtime(time));
$t=substr($t,0,-1); # ignore last digit of minutes just in case
like($msg->time, qr/$t\d\d\d/, "clock update time");
