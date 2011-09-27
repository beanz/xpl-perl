#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use Test::More tests => 54;
use t::Helpers qw/test_warn test_error test_output/;
use lib 't/lib';
$|=1;

use_ok('xPL::IORecord::Simple');

my $r = xPL::IORecord::Simple->new('test');
ok($r, 'xPL::IOR::Simple->new');
is($r->raw, 'test', 'xPL::IOR::Simple->raw');
is($r->out, 'test', 'xPL::IOR::Simple->out');
is(''.$r, 'test', 'xPL::IOR::Simple->str overloaded ""');
$r = xPL::IORecord::Simple->new(raw => 'test',
                                desc => 'description', data => 'data');
ok($r, 'xPL::IOR::Simple->new w/desc');
is(''.$r, 'test: description', 'xPL::IOR::Simple->str overloaded "" w/desc');
is($r->data, 'data', 'xPL::IOR::Simple->data');

is(test_error(sub { xPL::IORecord::Simple->new() }),
   "xPL::IORecord::Simple no message defined\n", 'xPL::IOR::Simple->new() error case');

foreach my $t ([CRLFLine => "\r\n"], [LFLine => "\n"], [CRLine => "\r"]) {
  my ($type, $eol) = @$t;
  my $class = 'xPL::IORecord::'.$type;
  use_ok($class);
  my $r = $class->new(raw => 'test', desc => 'description');
  ok($r, $class.'->new');
  is($r->out, 'test'.$eol, $class.'->out');
  is($r->str, 'test: description', $class.'->str');
  my $buf = $eol.'test'.$eol.'123';
  is($class->read($buf)->str, '', $class.'->read 1');
  is($class->read($buf)->str, 'test', $class.'->read 2');
  is($class->read($buf), undef, $class.'->read 3');
  is($buf, '123', $class.'->read remaining buffer');
}

use_ok('xPL::IORecord::VariableLength');
$r = xPL::IORecord::VariableLength->new(bits => 4,
                                        hex => 'f0',
                                        desc => 'description');
ok($r, 'xPL::IORecord::VariableLength->new');
is((unpack 'H*', $r->raw), '04f0', 'xPL::IORecord::VariableLength->raw');
is($r->bits, 4, 'xPL::IORecord::VariableLength->bits');
is($r->hex, 'f0', 'xPL::IORecord::VariableLength->hex');

my $class = 'xPL::IORecord::VariableLength';
my $buf = pack 'H*', '001f0102030408bc2f123456';
my $m = $class->read($buf);
is($m->hex, '', $class.'->read->hex 1');
is($m->bits, 0, $class.'->read->bits 1');

$m = $class->read($buf);
is($m->hex, '01020304', $class.'->read->hex 2');
is($m->bits, 31, $class.'->read->bits 2');
is($m->str, '1f01020304', $class.'->read->str 2');

$m = $class->read($buf);
# different order to exercise code
is($m->bits, 8, $class.'->read->bits 3');
is($m->hex, 'bc', $class.'->read->hex 3');
is($class->read($buf), 1, $class.'->read->hex 4');
is((unpack 'H*', $buf), '2f123456', $class.'->read remaining buffer');

$class = 'xPL::IORecord::ZeroSplitLine';
use_ok($class);
$buf = pack 'H*', '68656c6c6f00776f726c640a30';
$m = $class->read($buf);
is($m->str, 'hello world', $class.'->read 1');
$m = $class->new(fields => [qw/hello world/], desc => 'description');
ok($m, $class.'->new(fields => ..., desc ...)');
is($m->str, 'hello world: description', $class.'->new->str');

$class = 'xPL::IORecord::XML';
use_ok($class);
$buf = '<this><that>...</that><next>...</next>';
$m = $class->read($buf);
is($m->str, '<that>...</that>', $class.'->read->str');
is($buf, '<next>...</next>', $class.'->read remaining');
