#!#!/usr/bin/perl -w
#
# Copyright (C) 2009, 2010 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;
BEGIN {
  require Test::More;

  eval { require Net::Bluetooth; };
  if ($@) {
    import Test::More skip_all => 'No Net::Bluetooth perl module';
  }
  import Test::More tests => 10;
}

use_ok('xPL::Dock','Bluetooth');

my %devices = map { uc $_ => 1 } qw/00:1A:75:DE:DE:DE 00:1A:75:ED:ED:ED/;
{
  no warnings;
  no strict;
  *xPL::Dock::Bluetooth::sdp_search =
    sub { exists $devices{$_[0]} };
}

my @msg;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  push @msg, [@_];
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;

my $count = 0;
{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--bluetooth-verbose', '--bluetooth-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1', '00:1a:75:de:de:de');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::Bluetooth', 'plugin has correct type');
my $output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output,
   "sending xpl-trig/sensor.basic: bnz-dingus.mytestid -> * -".
   " bt.00:1A:75:DE:DE:DE[input]=high\n",
   'is found output');
check_sent_msg(xPL::Message->new(head => { source => $xpl->id },
                                 message_type => 'xpl-trig',
                                 class => 'sensor.basic',
                                 body =>
                                 {
                                  device => 'bt.00:1A:75:DE:DE:DE',
                                  type => 'input',
                                  current => 'high',
                                 }),
               'is found message');

$output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output,
   "sending xpl-stat/sensor.basic: bnz-dingus.mytestid -> * -".
   " bt.00:1A:75:DE:DE:DE[input]=high\n",
   'is still found output');
check_sent_msg(xPL::Message->new(head => { source => $xpl->id },
                                 message_type => 'xpl-stat',
                                 class => 'sensor.basic',
                                 body =>
                                 {
                                  device => 'bt.00:1A:75:DE:DE:DE',
                                  type => 'input',
                                  current => 'high',
                                 }),
               'is still found message');

delete $devices{'00:1A:75:DE:DE:DE'};
$plugin->{_verbose} = 0;

$output = test_output(sub { $xpl->dispatch_timer('poll-bluetooth') },
                         \*STDOUT);
is($output, '', 'not found output - not verbose');
check_sent_msg(xPL::Message->new(head => { source => $xpl->id },
                                 message_type => 'xpl-trig',
                                 class => 'sensor.basic',
                                 body =>
                                 {
                                  device => 'bt.00:1A:75:DE:DE:DE',
                                  type => 'input',
                                  current => 'low',
                                 }),
               'not found message');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while ((ref $msg->[0]) =~ /^xPL::Message::hbeat/) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $expected) {
    is_deeply($msg->[0], $expected, 'message as expected - '.$desc);
  } else {
    is(scalar @msg, 0, 'message not expected - '.$desc);
  }
}
