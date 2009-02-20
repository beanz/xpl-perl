#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2007 by Mark Hindess

use strict;
use DirHandle;
use English qw/-no_match_vars/;
use FileHandle;
my %yaml;
my $tests = 0;

BEGIN {
  my $SLASH = q{/};
  my $dir = 'lib/xPL/schema';
  my $dh = DirHandle->new($dir) or die "Open of $dir directory: $ERRNO\n";
  foreach (sort $dh->read) {
    next if (!/^(.*)\.yaml$/);
    my $name = $LAST_PAREN_MATCH;
    my $f = $dir.$SLASH.$_;
    $yaml{$name} = $f;
    $tests += 3;
  }
  $dh->close;
  require Test::More;
  import Test::More tests => $tests;
}

eval { require YAML; };
my $has_yaml = !$@;
eval { require YAML::Syck; };
my $has_yaml_syck = !$@;
SKIP: {
  skip 'YAML not available', $tests unless $has_yaml;
  skip 'YAML::Syck not available', $tests unless $has_yaml_syck;

  foreach my $name (sort keys %yaml) {
    my $file = $yaml{$name};
    my $yaml = YAML::LoadFile($file);
    ok($yaml, $name.' - YAML');
    my $syck = YAML::Syck::LoadFile($file);
    ok($syck, $name.' - YAML::SYCK');
    is_deeply($syck, $yaml, $name.' - YAML::Syck should match YAML');
  }
}
