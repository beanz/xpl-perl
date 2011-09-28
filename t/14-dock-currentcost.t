#!/usr/bin/perl -w
#
# Copyright (C) 2010 by Mark Hindess

use strict;
use IO::Socket::INET;
use IO::Select;
use Socket;
use t::Helpers qw/test_warn test_error test_output/;
use t::Dock qw/check_sent_message/;
no warnings qw/deprecated/;
$|=1;

BEGIN {
  require Test::More;
  eval { require AnyEvent::CurrentCost; import AnyEvent::CurrentCost; };
  if ($@) {
    import Test::More skip_all => 'No AnyEvent::CurrentCost module: '.$@;
  }
  import Test::More tests => 28;
}

use_ok('xPL::Dock','CurrentCost');

$ENV{XPL_HOSTNAME} = 'mytestid';
my $device = IO::Socket::INET->new(Listen => 5, LocalAddr => '127.0.0.1:0');
ok($device, 'creating fake tcp serial client');
my $sel = IO::Select->new($device);
my $port = $device->sockport();
my $xpl;

{
  local $0 = 'dingus';
  local @ARGV = ('-v',
                 '--interface', 'lo',
                 '--define', 'hubless=1',
                 '--currentcost-verbose',
                 '--currentcost-tty', '127.0.0.1:'.$port);
  $xpl = xPL::Dock->new(port => 0);
}
ok($xpl, 'created dock client');
ok($sel->can_read(0.5), 'device ready to accept');
my $client = $device->accept;
ok($client, 'client accepted');
my $client_sel = IO::Select->new($client);

my $plugin = ($xpl->plugins)[0];
ok($plugin, 'plugin exists');
is(ref $plugin, 'xPL::Dock::CurrentCost', 'plugin has correct type');

print $client q{
<msg><date><dsb>00001</dsb><hr>12</hr><min>17</min><sec>02</sec></date><src><name>CC02</name><id>02371</id><type>1</type><sver>1.06</sver></src><ch1><watts>02131</watts></ch1><ch2><watts>00000</watts></ch2><ch3><watts>00000</watts></ch3><tmpr>20.7</tmpr></msg>
};

is(test_output(sub { wait_for_message($plugin); }, \*STDOUT),
   q{cc128.02371.0.1/power/2131/W
cc128.02371.0.2/power/0/W
cc128.02371.0.3/power/0/W
cc128.02371.0/power/2131/W
cc128.02371.0/temp/20.7
},
   'read response - cc128');
foreach my $rec (['cc128.02371.0.1', 'power', "2131\nunits=W"],
                 ['cc128.02371.0.2', 'power', "0\nunits=W"],
                 ['cc128.02371.0.3', 'power', "0\nunits=W"],
                 ['cc128.02371.0', 'power', "2131\nunits=W"],
                 ['cc128.02371.0', 'temp', '20.7'],
                ) {
  my ($device, $type, $current) = @$rec;
  check_sent_message($device => qq!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=$device
type=$type
current=$current
}
!);
}
print $client q{
<msg>
   <src>CC128-v0.11</src>
   <dsb>00089</dsb>
   <time>13:02:39</time>
   <tmpr>18.7</tmpr>
   <sensor>1</sensor>
   <id>01234</id>
   <type>1</type>
   <ch1>
      <watts>00345</watts>
   </ch1>
   <ch2>
      <watts>02151</watts>
   </ch2>
   <ch3>
      <watts>00000</watts>
   </ch3>
</msg>
};

is(test_output(sub { wait_for_message($plugin); }, \*STDOUT),
   q{cc128.01234.1.1/power/345/W
cc128.01234.1.2/power/2151/W
cc128.01234.1.3/power/0/W
cc128.01234.1/power/2496/W
cc128.01234.1/temp/18.7
},
   'read response - cc128');
foreach my $rec (['cc128.01234.1.1', 'power', "345\nunits=W"],
                 ['cc128.01234.1.2', 'power', "2151\nunits=W"],
                 ['cc128.01234.1.3', 'power', "0\nunits=W"],
                 ['cc128.01234.1', 'power', "2496\nunits=W"],
                 ['cc128.01234.1', 'temp', '18.7'],
                ) {
  my ($device, $type, $current) = @$rec;
  check_sent_message($device => qq!xpl-trig
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=$device
type=$type
current=$current
}
!);
}

print $client q{
<msg>
   <src>CC128-v0.11</src>
   <dsb>00089</dsb>
   <time>13:10:50</time>
   <hist>
      <dsw>00032</dsw>
      <type>1</type>
      <units>kwhr</units>
      <data>
         <sensor>0</sensor>
         <h024>001.1</h024>
         <h022>000.9</h022>
         <h020>000.3</h020>
         <h018>000.4</h018>
      </data>>
   </hist>>
</msg>
};

is(test_output(sub { wait_for_message($plugin); }, \*STDOUT),
   q{}, 'historical data ignored');
check_sent_message('historical data ignored');

print $client q{
<msg>
   <src>CC128-v0.11</src>
   <dsb>02999</dsb>
   <time>13:02:39</time>
   <tmpr>18.7</tmpr>
};

is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   '', 'ignoring partial message');

print $client q{   <sensor>1</sensor>
   <id>01234</id>
   <type>2</type>
   <ch1>
      <medichlorians>01345</medichlorians>
   </ch1>
   <ch2>
      <medichlorians>12151</medichlorians>
   </ch2>
   <ch3>
      <medichlorians>00099</medichlorians>
   </ch3>
</msg>
};
is(test_output(sub { $xpl->main_loop(1); }, \*STDERR),
   q{Sensor type: 2 not supported.  Message was:
<msg>
   <src>CC128-v0.11</src>
   <dsb>02999</dsb>
   <time>13:02:39</time>
   <tmpr>18.7</tmpr>
   <sensor>1</sensor>
   <id>01234</id>
   <type>2</type>
   <ch1>
      <medichlorians>01345</medichlorians>
   </ch1>
   <ch2>
      <medichlorians>12151</medichlorians>
   </ch2>
   <ch3>
      <medichlorians>00099</medichlorians>
   </ch3>
</msg>
},
   'new sensor type');
check_sent_message('new sensor type' => qq!xpl-stat
{
hop=1
source=bnz-dingus.mytestid
target=*
}
sensor.basic
{
device=cc128.01234.1
type=temp
current=18.7
}
!);

print $client q{<invalid>
</invalid>
};
is(test_output(sub { $xpl->main_loop(1); }, \*STDOUT), '',
   'invalid tag ignored');
check_sent_message('invalid tag ignored');

print $client q{
<msg><date><dsb>00001</dsb><hr>12</hr><min>17</min><sec>02</sec></date><src><name>CC02</name><id>02371</id><type>1</type><sver>1.06</sver></src><ch1><watts>02132</watts></ch1><ch2><watts>00000</watts></ch2><ch3><watts>00000</watts></ch3><tmpr>20.8</tmpr></msg>
};

is(test_output(sub { wait_for_message($plugin); }, \*STDOUT),
   q{cc128.02371.0.1/power/2132/W
cc128.02371.0/power/2132/W
cc128.02371.0/temp/20.8
},
   'read response - cc128');

# The begin block is global of course but this is where it is really used.
BEGIN{
  *CORE::GLOBAL::exit = sub { die "EXIT\n" };
  require Pod::Usage; import Pod::Usage;
}
{
  local @ARGV = ('-v', '--interface', 'lo', '--define', 'hubless=1');
  is(test_output(sub {
                   eval { $xpl = xPL::Dock->new(port => 0, name => 'dingus'); }
                 }, \*STDOUT),
     q{Listening on 127.0.0.1:3865
Sending on 127.0.0.1
The --currentcost-tty parameter is required
or the value can be given as a command line argument
}, 'missing parameter');
}

sub wait_for_message {
  my ($plugin) = shift;
  undef $plugin->{_got_message};
  do {
    AnyEvent->one_event;
  } until ($plugin->{_got_message});
}
