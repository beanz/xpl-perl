#!#!/usr/bin/perl -w
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

  unless (exists $ENV{DISPLAY}) {
    import Test::More skip_all => 'No X11 DISPLAY defined';
    exit;
  }

  eval {
    require X::Osd; import X::Osd;
  };
  if ($@) {
    import Test::More skip_all => 'No X::Osd perl module';
  }

  import Test::More tests => 23;
}

use_ok('xPL::Dock','XOSD');

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
                 '--xosd-verbose', '--xosd-verbose',
                 '--interface', 'lo',
                 '--define', 'hubless=1');
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::XOSD', 'plugin has correct type');

is(ref $plugin->{_xosd}, 'X::Osd', 'X::Osd created');

{
  package MyXOsd;
  sub new { bless { calls => [] }, 'MyXOsd' }
  sub calls { splice @{$_[0]->{calls}} }
  sub AUTOLOAD {
    my $self = shift;
    our $AUTOLOAD;
    push @{$self->{calls}}, "$AUTOLOAD @_";
  }
  sub DESTROY {}
  1;
}
my $mock = $plugin->{_xosd} = MyXOsd->new();

my $msg = xPL::Message->new(message_type => 'xpl-cmnd',
                            head => { source => 'acme-xosd.test' },
                            class => 'osd.basic',
                            body => [ command => 'write', text => 'test' ]);
$xpl->dispatch_xpl_message($msg);
my @calls = $mock->calls;
is(scalar @calls, 2, 'correct number of calls - 2');
is($calls[0], "MyXOsd::set_timeout 10", "'set_timeout 10' called");
is($calls[1], "MyXOsd::string 0 test", "'string 0 test' called");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-xosd.test' },
                         class => 'osd.basic',
                         body => [ command => 'clear', text => 'test',
                                   row => 2, delay => 4 ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 7, 'correct number of calls - 7');
is($calls[0], "MyXOsd::set_timeout 0", "'set_timeout 0' called");
is($calls[1], "MyXOsd::string 0 ", "'string 0 ' called");
is($calls[2], "MyXOsd::string 1 ", "'string 1 ' called");
is($calls[3], "MyXOsd::string 2 ", "'string 2 ' called");
is($calls[4], "MyXOsd::string 3 ", "'string 3 ' called");
is($calls[5], "MyXOsd::set_timeout 4", "'set_timeout 4' called");
is($calls[6], "MyXOsd::string 1 test", "'string 1 test' called");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-xosd.test' },
                         class => 'osd.basic',
                         body => [ command => 'write', text => 'test',
                                   row => 5, delay => 90 ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 2, 'correct number of calls - row out of range');
is($calls[0], "MyXOsd::set_timeout 10", "'set_timeout 10' called");
is($calls[1], "MyXOsd::string 0 test", "'string 0 test' called");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-xosd.test' },
                         class => 'osd.basic',
                         body => [ command => 'write', text => 'test',
                                   row => -1 ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 2, 'correct number of calls - row out of range');
is($calls[0], "MyXOsd::set_timeout 10", "'set_timeout 10' called");
is($calls[1], "MyXOsd::string 0 test", "'string 0 test' called");

$msg = xPL::Message->new(message_type => 'xpl-cmnd',
                         head => { source => 'acme-xosd.test' },
                         class => 'osd.basic',
                         body => [ command => 'write', ]);
$xpl->dispatch_xpl_message($msg);
@calls = $mock->calls;
is(scalar @calls, 0, 'no calls for empty write');

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
