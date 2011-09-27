#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
$|=1;

BEGIN {
  require Test::More;

  eval {
    require DateTime::Event::Sunrise;
  };
  if ($@) {
    import Test::More skip_all => 'No DateTime::Event::Sunrise perl module';
  }
  import Test::More tests => 19;
}

use_ok('xPL::Dock','DawnDusk');

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
                 '--dawndusk-verbose', '--dawndusk-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DawnDusk', 'plugin has correct type');
my $state = $plugin->state;
my $opposite = { day => 'night', 'night' => 'day' }->{$state};


my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            head => { source => 'acme-dawndusk.test' },
                            schema => 'dawndusk.request');
$xpl->dispatch_xpl_message($msg);
check_sent_msg({ message_type => 'xpl-stat',
                 schema => 'dawndusk.basic',
                 body => [
                          type => 'daynight',
                          status => $state,
                         ]
               }, 'response - 1');

my $timers =
  { 'day' => ['dusk', 'dawn'], 'night' => ['dawn','dusk'] }->{$state};
foreach my $timer (@$timers) {
  is(test_output(sub { $xpl->dispatch_timer($timer) } , \*STDOUT),
     (ucfirst $timer)."\n");
  check_sent_msg({ message_type => 'xpl-trig',
                   schema => 'dawndusk.basic',
                   body => [
                            type => 'dawndusk',
                            status => $timer,
                           ]
                 }, 'response - verbose '.$timer);
}
$plugin->{_verbose} = 0;
foreach my $timer (@$timers) {
  is(test_output(sub { $xpl->dispatch_timer($timer) } , \*STDOUT), '');
  check_sent_msg({ message_type => 'xpl-trig',
                   schema => 'dawndusk.basic',
                   body => [
                            type => 'dawndusk',
                            status => $timer,
                           ]
                 }, 'response - verbose '.$timer);
}

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--dawndusk-verbose', '--dawndusk-verbose',
                 '--dawndusk-longitude' => +179,
                 '--dawndusk-latitude' => -51,
                 '--dawndusk-altitude' => -0.583,
                 '--dawndusk-iteration' => 1,
                 '--interface', 'lo',
                 '--define', 'hubless=1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DawnDusk', 'plugin has correct type');
is($plugin->state, $opposite, 'check opposite state');
is($plugin->altitude, -0.583, 'check altitude');
is($plugin->iteration, 1, 'check iteration');

sub check_sent_msg {
  my ($expected, $desc) = @_;
  my $msg = shift @msg;
  while ($msg->[0] && ref $msg->[0] eq 'xPL::Message' &&
         $msg->[0]->schema =~ /^hbeat\./) {
    $msg = shift @msg; # skip hbeat.* message
  }
  if (defined $expected) {
    my %m = @{$msg};
    is_deeply(\%m, $expected, 'message as expected - '.$desc);
  } else {
    is(scalar @msg, 0, 'message not expected - '.$desc);
  }
}
