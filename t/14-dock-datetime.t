#!/usr/bin/perl -w
#
# Copyright (C) 2010 by Mark Hindess

use strict;
use POSIX qw/strftime/;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
no warnings qw/deprecated/;
$|=1;

BEGIN {
  require Test::More;

  import Test::More tests => 11;
}

use_ok('xPL::Dock','DateTime');

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
                 '--datetime-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--datetime-interval', -1);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DateTime', 'plugin has correct type');
ok($xpl->exists_timer('datetime'), 'datetime timer');

$xpl->main_loop(1);
my $time = time;
my $datetime = strftime "%Y%m%d%H%M%S", localtime $time;

check_sent_msg({ message_type => 'xpl-trig',
                 schema => 'datetime.basic',
                 body => [
                          datetime => $datetime,
                          date => (substr $datetime, 0, 8, ''),
                          time => $datetime,
                          epoch => $time,
                         ]
               }, 'tick message');

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            head => { source => 'acme-datetime.test' },
                            schema => 'datetime.request');
$xpl->dispatch_xpl_message($msg);
$time = time;
$datetime = strftime "%Y%m%d%H%M%S", localtime $time;

check_sent_msg({ message_type => 'xpl-stat',
                 schema => 'datetime.basic',
                 body => [
                          status => $datetime,
                          epoch => $time,
                         ]
               }, 'response');

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--datetime-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--datetime-interval', 0);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::DateTime', 'plugin has correct type');
ok(!$xpl->exists_timer('datetime'), 'no datetime timer');

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
