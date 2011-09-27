#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
use lib 't/lib';
$|=1;

use Test::More tests => 10;

use_ok('xPL::Dock','FDNotify');

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
                 '--fdnotify-verbose', '--fdnotify-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::FDNotify', 'plugin has correct type');
my $mock = $plugin->{_dbus_object};

is(ref $mock, 'Net::DBus::RemoteObject', 'DBUS object created');

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            head => { source => 'acme-fdnotify.test' },
                            schema => 'osd.basic',
                            body => [ command => 'write', text => 'test' ]);
$xpl->dispatch_xpl_message($msg);
my @calls = $mock->calls;
is(scalar @calls, 1, 'correct number of calls - 1');
is($calls[0], q!Net::DBus::RemoteObject::Notify $args = [
          'dingus',
          0,
          '',
          'test',
          '',
          [],
          {},
          -1
        ];
!, "called - 1");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-fdnotify.test' },
                         schema => 'osd.basic',
                         body => [ command => 'write', text => 'test',
                                   delay => 90 ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 1, 'correct number of calls - delay given');
is($calls[0], q!Net::DBus::RemoteObject::Notify $args = [
          'dingus',
          0,
          '',
          'test',
          '',
          [],
          {},
          90000
        ];
!, "called - 2");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-fdnotify.test' },
                         schema => 'osd.basic',
                         body => [ command => 'write', ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 0, 'no calls for empty write');

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
