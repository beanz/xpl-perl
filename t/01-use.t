#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use English qw/-no_match_vars/;
use FileHandle;
my @modules;

BEGIN {
  my $fh = FileHandle->new('<MANIFEST') or
    die 'Open of MANIFEST failed: '.$ERRNO;
  while(<$fh>) {
    next if (!/^lib\/(.*)\.pm/);
    my $m = $LAST_PAREN_MATCH;
    $m =~ s!/!::!g;
    push @modules, $m;
  }
  $fh->close;
  require Test::More;
  import Test::More tests => scalar @modules;
}

my %has;
eval { require DateTime::Event::Cron; };
$has{Cron}++ unless ($@);
eval { require DateTime::Event::Sunrise; };
$has{Sunrise}++ unless ($@);
eval { require DateTime::Event::Recurrence; };
$has{Recurrence}++ unless ($@);
eval { require Gtk2; };
$has{Gtk2}++ unless ($@);


foreach my $m (@modules) {
 SKIP: {
    skip 'no database defined, see xPL::SQL', 1
      if ($m eq 'xPL::SQL' && !exists $ENV{'XPL_DB_CONFIG'});
    skip 'DateTime::Event::Cron not available', 1
      if ($m eq 'xPL::Timer::cron' && !$has{Cron});
    skip 'DateTime::Event::Sunrise not available', 1
      if ($m eq 'xPL::Timer::sunrise' && !$has{Sunrise});
    skip 'DateTime::Event::Sunrise not available', 1
      if ($m eq 'xPL::Timer::sunset' && !$has{Sunrise});
    skip 'DateTime::Event::Recurrence not available', 1
      if ($m eq 'xPL::Timer::recurrence' && !$has{Recurrence});
    skip 'Gtk2 not available', 1 if ($m eq 'xPL::Gtk2Client' && !$has{Gtk2});

    require_ok($m);
  }
}
