#!/usr/bin/perl -w
use strict;
use DirHandle;
use FileHandle;
use English qw/-no_match_vars/;
use xPL::Base;

my @paths;

BEGIN {
  my $dir = 't/interfaces';
  my $dh = DirHandle->new($dir) or die "Failed to open $dir: ".$ERRNO;
  foreach my $d ($dh->read) {
    next if ($d =~ /^\./);
    my $fp = $dir.'/'.$d;
    next unless (-d $fp);
    push @paths, $fp;
  }
  $dh->close;
  require Test::More;
  import Test::More tests => 13 + 7 * scalar @paths;
}

{
  package xPL::Test;
  our @ISA=qw/xPL::Base/;
  sub new {
    my $pkg = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
  }
}

# test the parsing by abusing the PATH variable to run some wrappers
foreach my $path (@paths) {
  $ENV{PATH} = $path;
  my $test = xPL::Test->new();
  ok($test, "test object - $path");
  my $src = -f $path.'/ifconfig' ? 'ifconfig' : 'ip';
  my $method = 'interfaces_'.$src;
  my $list = $test->$method();
  ok($list, "interfaces - $path");
  is(@$list, 2, "interfaces length - $path");
  is($list->[0]->{device}, 'eth0', "interfaces device - $path");
  is($list->[0]->{src}, $src, "interfaces src - $path");
  is($list->[0]->{ip}, '192.168.3.13', "interfaces ip - $path");
  is($list->[0]->{broadcast}, '192.168.3.255', "interfaces broadcast - $path");
}

# finally test the higher level methods with one of the paths
$ENV{PATH} = 't/interfaces/ifconfig.linux';
my $test = xPL::Test->new();
ok($test, "test object - main");
my $info = $test->default_interface_info();
ok($info, "default interface");
is($info->{device}, 'eth0', 'default interface device');
is($info->{src}, 'ifconfig', 'default interface src');
is($info->{ip}, '192.168.3.13', 'default interface ip');
is($info->{broadcast}, '192.168.3.255', 'default interface broadcast');

$info = $test->interface_info('vmnet8');
ok($info, 'specific interface');
is($info->{device}, 'vmnet8', 'specific interface device');
is($info->{src}, 'ifconfig', 'specific interface src');
is($info->{ip}, '192.168.165.1', 'specific interface ip');
is($info->{broadcast}, '192.168.165.255', 'specific interface broadcast');

ok(!$test->interface_info('ppp0'), 'non-existent interface');

# let's fake the interfaces list and test the failure case
$test->{_interfaces} =
  [
   { device => 'lo', ip => '127.0.0.1', broadcast => '127.255.255.255',
     src => 'manual hack' },
  ];

ok(!$test->default_interface_info(), "failure case - nothing but loopback");
