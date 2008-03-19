#!/usr/bin/perl -w
#
# Copyright (C) 2008 by Mark Hindess

use strict;
use Test::More tests => 281;
$|=1;

use_ok('xPL::Queue');

my $q = xPL::Queue->new();
ok($q, 'test xpl queue object create');

ok($q->is_empty, 'is empty initially');
is($q->length, 0, 'length is 0 initially');
ok(!defined $q->dequeue, 'dequeue when empty');
ok(!defined $q->average_queue_time, 'average_queue_time when empty');
is($q->number_of_queue_time_samples, 0, 'no queue time samples initially');

$q->enqueue('test');
ok(!$q->is_empty, 'is not empty');
is($q->length, 1, 'length is 1');
ok(!defined $q->average_queue_time, 'average_queue_time when still queued');
is($q->number_of_queue_time_samples, 0,
   'no queue time samples when still queued');
is($q->dequeue, 'test', 'dequeue when not empty');
is($q->length, 0, 'length is 0 initially');
ok(!defined $q->dequeue, 'dequeue when empty');
ok(defined $q->average_queue_time, 'average_queue_time');
is($q->number_of_queue_time_samples, 1, 'one queue time sample');

foreach (1..53) {
  $q->enqueue($_);
  is($q->length, $_, 'length is '.$_);
  is($q->number_of_queue_time_samples, 1,
     'queue time samples when still queued');
}
foreach (1..53) {
  is($q->dequeue, $_, 'dequeue '.$_);
  is($q->length, 53-$_, 'length is '.(53-$_));
  my $samples = $_ >= 50 ? 50 : 1+$_;
  is($q->number_of_queue_time_samples, $samples,
     $samples.' queue time samples');
}
