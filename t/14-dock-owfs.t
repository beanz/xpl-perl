#!#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use Test::More tests => 13;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

use_ok('xPL::Dock','Owfs');

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;
my $plugin;

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', 't/ow/1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Owfs', 'plugin has correct type');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   'CRC8 error rate   0.01
CRC16 error rate   0.00
1st try read success  99.99
2nd try read success   0.01
3rd try read success  54.80
        read failure -54.79
1st try write success 100.00
2nd try write success   0.00
3rd try write success   0.00
        write failure   0.00
',
   'output 1');

check_sent_msg({
                'body' => {
                           'current' => '20.1',
                           'type' => 'temp',
                           'device' => '28.FEFEFE000000'
                          },
                'message_type' => 'xpl-trig',
                'class' => 'sensor.basic'
               }, 'temp reported');

$plugin->owfs_reader();
check_sent_msg({
                'body' => {
                           'current' => '20.1',
                           'type' => 'temp',
                           'device' => '28.FEFEFE000000'
                          },
                'message_type' => 'xpl-stat',
                'class' => 'sensor.basic'
               }, 'temp reported');

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', 't/ow/2');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Owfs', 'plugin has correct type');

is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT),
   'CRC8 error rate   0.00
CRC16 error rate   0.00
1st try read success 100.00
2nd try read success   0.00
3rd try read success   0.00
        read failure   0.00
1st try write success 100.00
2nd try write success   0.00
3rd try write success   0.00
        write failure   0.00
',
   'output 2');

check_sent_msg({
                'body' => {
                           'current' => '25.8438',
                           'type' => 'temp',
                           'device' => '26.ABABAB000000'
                          },
                'message_type' => 'xpl-trig',
                'class' => 'sensor.basic'
               }, 'temp reported');
check_sent_msg({
                'body' => {
                           'current' => '24.6653',
                           'type' => 'humidity',
                           'device' => '26.ABABAB000000'
                          },
                'message_type' => 'xpl-trig',
                'class' => 'sensor.basic'
               }, 'humidity reported');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while ((ref $msg->[0]) =~ /^xPL::Message::hbeat/) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $expected) {
    my %m = @{$msg};
    is_deeply(\%m, $expected, 'message as expected - '.$desc);
  } else {
    is(scalar @msg, 0, 'message not expected - '.$desc);
  }
}
