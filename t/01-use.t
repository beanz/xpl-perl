#!/usr/bin/perl -w
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

foreach my $m (@modules) {
 SKIP: {
    skip 'no database defined, see xPL::SQL', 1
      if ($m eq 'xPL::SQL' && !exists $ENV{'XPL_DB_CONFIG'});

    require_ok($m);
  }
}
