#!/usr/bin/perl -w
use strict;
use DirHandle;
use English qw/-no_match_vars/;
use FileHandle;
use t::Helpers qw/test_warn test_error/;
use Test::More tests => 64;
$|=1;
use_ok('xPL::Timer');

my $t;
$t = xPL::Timer->new(type => 'simple', timeout => 10, verbose => 1);
ok($t, 'create simple timer');
isa_ok($t, 'xPL::Timer::simple', 'simple timer type');
is($t->next(23), 33, 'simple timer next value');

$t = xPL::Timer->new_from_string('10');
ok($t, 'create simple timer from string');
isa_ok($t, 'xPL::Timer::simple', 'simple timer type from string');
is($t->next(23), 33, 'simple timer next value from string');

is(test_error(sub { xPL::Timer->new(); }),
   q{xPL::Timer::simple->init: requires 'timeout' parameter},
   'simple timer missing timeout error');

is(test_error(sub { xPL::Timer->new(type => 'simple', timeout => 'xxx'); }),
   q{xPL::Timer::simple->init: invalid 'timeout' parameter},
   'simple timer invalid timeout error');

SKIP_CRON: {
  eval { require DateTime::Event::Cron; };
  skip "DateTime::Event::Cron is not available", 12 if $@;

  $t = xPL::Timer->new(type => 'cron', crontab => '17 * * * *', verbose => 1);
  ok($t, 'create cron timer');
  isa_ok($t, 'xPL::Timer::cron', 'cron timer type');
  is($t->next(23), 1020, 'cron timer next value');

  $t = xPL::Timer->new_from_string('cron crontab="17 * * * *"');
  ok($t, 'create cron timer from string');
  isa_ok($t, 'xPL::Timer::cron', 'cron timer type from string');
  is($t->next(23), 1020, 'cron timer next value from string');

  $t = xPL::Timer->new(type => 'cron', crontab => '17 * * * *',
                       tz => 'Asia/Katmandu');
  ok($t, 'create cron timer');
  isa_ok($t, 'xPL::Timer::cron', 'cron timer type');
  is($t->next(23), 2820, 'cron timer next value');

  $t = xPL::Timer->new(type => 'cron', crontab => '* * * * *', tz => 'UTC');
  ok($t, 'create cron timer');
  isa_ok($t, 'xPL::Timer::cron', 'cron timer type');
  my $time = time;
  my $sec = (gmtime $time)[0];
  is($t->next(), $time + (60-$sec), 'cron timer next value');
}

SKIP_SUN: {
  eval { require DateTime::Event::Sunrise; };
  skip "DateTime::Event::Sunrise is not available", 42 if $@;

  foreach ([ sunrise => 29240 ], [ sunset => 58098 ]) {
    my ($type, $time) = @$_;

    $t = xPL::Timer->new(type => $type,
                         latitude => 51, longitude => -1,
                         altitude => -0.833, iteration => 1,
                         tz => 'Europe/London');
    ok($t, 'create timer - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type - '.$type);
    is($t->next(23), $time, 'timer next value - '.$type);

    $t = xPL::Timer->new_from_string($type.' latitude=51 longitude=-1 '.
                                     'altitude=-0.833 iteration=1 '.
                                     'tz="Europe/London"');
    ok($t, 'create timer from string - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type from string - '.$type);
    is($t->next(23), $time, 'timer next value from string - '.$type);

    my $set =
      DateTime::Event::Sunrise->$type(latitude => 51, longitude => -1,
                                      altitude => -0.833, iteration => 1);
    my $next = $set->next(DateTime->now());
    is($t->next(), $next->epoch, 'timer next value from now - '.$type);

    $ENV{LATITUDE} = 51;
    $ENV{LONGITUDE} = -1;
    $t = xPL::Timer->new(type => $type);
    ok($t, 'create timer - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type - '.$type);
    is($t->next(23), $time, 'timer next value - '.$type);
    delete $ENV{LATITUDE};
    delete $ENV{LONGITUDE};

    $t = xPL::Timer->new(type => $type, hours => 1,
                         latitude => 51, longitude => -1);
    ok($t, 'create timer w/offset - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type - '.$type);
    is($t->next(23), $time+3600, 'timer w/offset next value - '.$type);

    $t = xPL::Timer->new(type => $type, minutes => 30,
                         latitude => 51, longitude => -1);
    ok($t, 'create timer w/offset - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type - '.$type);
    is($t->next(23), $time+1800, 'timer w/offset next value - '.$type);

    $t = xPL::Timer->new(type => $type, seconds => 120,
                         latitude => 51, longitude => -1);
    ok($t, 'create timer w/offset - '.$type);
    isa_ok($t, 'xPL::Timer::'.$type, 'timer type - '.$type);
    is($t->next(23), $time+120, 'timer w/offset next value - '.$type);

    is(test_error(sub { xPL::Timer->new(type => $type) }),
       qq{xPL::Timer::$type->init: requires 'latitude' parameter
or LATITUDE environment variable},
       'missing latitude - '.$type);
    is(test_error(sub { xPL::Timer->new(type => $type, latitude => 51) }),
       qq{xPL::Timer::$type->init: requires 'longitude' parameter
or LONGITUDE environment variable},
       'missing longitude - '.$type);
  }
}

is(test_error(sub { $t = xPL::Timer->new(type => 'testing') }),
   q{xPL::Timer->new: Failed to load xPL::Timer::testing: }.
     q{Can't locate xPL/Timer/testing.pm in @INC},
   'testing non-existent Timer type');
