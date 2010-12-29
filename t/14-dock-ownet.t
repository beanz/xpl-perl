#!#!/usr/bin/perl -w
#
# Copyright (C) 2010 by Mark Hindess

use strict;

$|=1;

BEGIN {
  require Test::More;
  eval { require AnyEvent; import AnyEvent;
         require AnyEvent::Socket; import AnyEvent::Socket };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::Socket module installed: $@';
  }
  import Test::More;
  use t::Helpers qw/:all/;
}

use xPL::Message;

my @connections =
  (
   [
    {
     desc => q{getslash('/')},
     recv => '00 00 00 00 00 00 00 02  00 00 00 0A 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 00',
     send => '00 00 00 00 00 00 00 5e  00 00 00 00 00 00 01 0a
              00 00 00 5e 00 00 c0 02
              2f31302e4130463742313030303830302f2c
              2f6275732e302f2c
              2f73657474696e67732f2c
              2f73797374656d2f2c
              2f737461746973746963732f2c
              2f7374727563747572652f2c
              2f73696d756c74616e656f75732f2c
              2f616c61726d2f
              00',
    },

    {
     desc => q{get('/10.A0F7B1000800/temperature')},
     recv => '00 00 00 00 00 00 00 1D  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 74 65 6D 70 65 72 61
              74 75 72 65 00',
     send => '00 00 00 00 00 00 00 0c  00 00 00 0c 00 00 01 0a
              00 00 00 0c 00 00 00 00  20 20 20 20 20 20 32 33
              2e 36 32 35',
    },

    {
     desc => q{get('/10.A0F7B1000800/humidity')},
     recv => '00 00 00 00 00 00 00 1A  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 68 75 6D 69 64 69 74
              79 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{get('/10.A0F7B1000800/HIH4000/humidity')},
     recv => '00 00 00 00 00 00 00 22  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 48 49 48 34 30 30 30
              2F 68 75 6D 69 64 69 74  79 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{get('/10.A0F7B1000800/HTM1735/humidity')},
     recv => '00 00 00 00 00 00 00 22  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 48 54 4D 31 37 33 35
              2F 68 75 6D 69 64 69 74  79 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{get('/10.A0F7B1000800/counters.A')},
     recv => '00 00 00 00 00 00 00 1C  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 63 6F 75 6E 74 65 72
              73 2E 41 00',
     send => '00 00 00 00 00 00 00 0c  00 00 00 0c 00 00 01 0a
              00 00 00 0c 00 00 00 00  20 20 20 20 20 20 32 33
              33 36 32 35',
    },

    {
     desc => q{get('/10.A0F7B1000800/counters.B')},
     recv => '00 00 00 00 00 00 00 1C  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 63 6F 75 6E 74 65 72
              73 2E 42 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{get('/10.A0F7B1000800/current')},
     recv => '00 00 00 00 00 00 00 19  00 00 00 08 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 63 75 72 72 65 6E 74
              00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{getslash('/10.A0F7B1000800/')},
     recv => '00 00 00 00 00 00 00 12  00 00 00 0A 00 00 01 0E
              00 00 80 E8 00 00 00 00  2F 31 30 2E 41 30 46 37
              42 31 30 30 30 38 30 30  2F 00',
     send => '00 00 00 00 00 00 00 00  ff ff ff d6 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{write('/05.87102D000000/PIO', 1)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 38 37 31 30
              32 44 30 30 30 30 30 30  2F 50 49 4F 00 31',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    {
     desc => q{write('/05.87102D000000/PIO', 0)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 38 37 31 30
              32 44 30 30 30 30 30 30  2F 50 49 4F 00 30',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },


    { # pulse part 1, high
     desc => q{write('/05.87102D000000/PIO', 1)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 38 37 31 30
              32 44 30 30 30 30 30 30  2F 50 49 4F 00 31',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    { # pulse part 2, low
     desc => q{write('/05.87102D000000/PIO', 0)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 38 37 31 30
              32 44 30 30 30 30 30 30  2F 50 49 4F 00 30',
     send => '00 00 00 00 00 00 00 00  00 00 00 00 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

    { # pulse part 1, high failure
     desc => q{write('/05.87102D000000/PIO', 1)},
     recv => '00 00 00 00 00 00 00 16  00 00 00 03 00 00 01 0E
              00 00 00 01 00 00 00 00  2F 30 35 2E 38 37 31 30
              32 44 30 30 30 30 30 30  2F 50 49 4F 00 31',
     send => '00 00 00 00 00 00 00 00  ff ff ff fe 00 00 01 0a
              00 00 00 00 00 00 00 00',
    },

   ],

  );

my $cv = AnyEvent->condvar;
my $server;

eval { $server = test_server($cv, @connections) };
plan skip_all => "Failed to create dummy server: $@" if ($@);

my ($host,$port) = @{$cv->recv};
my $addr = join ':', $host, $port;

plan tests => 27;

use_ok('xPL::Dock','OWNet');

my @msg;
my $count = 0;
sub xPL::Dock::send_aux {
  my $self = shift;
  my $sin = shift;
  return if (ref $_[0] && $_[0]->schema =~ /^hbeat\./);
  push @msg, [@_];
  print STDERR $_[0]->summary, "\n" if (ref $_[0]);
  $count++;
}

$ENV{XPL_HOSTNAME} = 'mytestid';
my $xpl;
my $plugin;

{
  local $0 = 'dingus';
  local @ARGV = ('--verbose',
                 '--interface' => 'lo',
                 '--define' => 'hubless=1',
                 '--ownet-host' => $host,
                 '--ownet-port' => $port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
$plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::OWNet', 'plugin has correct type');

wait_for_variable($xpl, \$count);

my %m;

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'sensor.basic',
           body => [
                    device => '10.A0F7B1000800',
                    type => 'temp',
                    current => '23.625',
                   ],
          },
          '1st message sent');

wait_for_variable($xpl, \$count);

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'sensor.basic',
           body => [
                    device => '10.A0F7B1000800.0',
                    type => 'count',
                    current => '233625',
                   ],
          },
          '2nd message sent');

my $m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => 'udin.01',
                                   type => 'output',
                                   current => 'tweak',
                                  ]);
is(test_warn(sub { $xpl->dispatch_xpl_message($m); }),
   undef, 'no warning for non-1-wire device');

$m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => '05.87102D000000',
                                   type => 'output',
                                   current => 'high',
                                  ]);
$xpl->dispatch_xpl_message($m);

wait_for_variable($xpl, \$count);

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'control.confirm',
           body => [
                    device => '05.87102D000000',
                    type => 'output',
                    current => 'high',
                   ],
          },
          '3rd message sent');

$m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => '05.87102D000000',
                                   type => 'output',
                                   current => 'low',
                                  ]);
$xpl->dispatch_xpl_message($m);

wait_for_variable($xpl, \$count);

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'control.confirm',
           body => [
                    device => '05.87102D000000',
                    type => 'output',
                    current => 'low',
                   ],
          },
          '4th message sent');

$m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => '05.87102D000000',
                                   type => 'output',
                                   current => 'pulse',
                                  ]);
$xpl->dispatch_xpl_message($m);

wait_for_variable($xpl, \$count);

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'control.confirm',
           body => [
                    device => '05.87102D000000',
                    type => 'output',
                    current => 'pulse',
                   ],
          },
          '5th message sent');

# send pulse again - this time server returns failure on the high setting
$m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => '05.87102D000000',
                                   type => 'output',
                                   current => 'pulse',
                                  ]);
$xpl->dispatch_xpl_message($m);

wait_for_variable($xpl, \$count);

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'control.confirm',
           body => [
                    device => '05.87102D000000',
                    type => 'output',
                    current => 'error',
                   ],
          },
          '6th message sent');

$m = xPL::Message->new(message_type => 'xpl-cmnd',
                          head => { source => 'acme-ownet.test' },
                          schema => 'control.basic',
                          body => [
                                   device => '05.87102D000000',
                                   type => 'output',
                                   current => 'tweak',
                                  ]);
is(test_warn(sub { $xpl->dispatch_xpl_message($m); }),
   "Unsupported setting: tweak\n", 'unsupported setting');

%m = @{shift @msg};
is_deeply(\%m,
          {
           message_type => 'xpl-trig',
           schema => 'control.confirm',
           body => [
                    device => '05.87102D000000',
                    type => 'output',
                    current => 'error',
                   ],
          },
          '7th message sent');

