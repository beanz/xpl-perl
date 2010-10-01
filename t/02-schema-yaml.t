#!/usr/bin/perl -w
#
# Copyright (C) 2009 by Mark Hindess

use strict;
use DirHandle;
use English qw/-no_match_vars/;
use Test::More;
my %yaml;

my $tests = 0;
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
eval { require YAML; };
if ($@) {
  plan skip_all => 'YAML not available';
}
eval { require YAML::Syck; };
if ($@) {
  plan skip_all => 'YAML::Syck not available';
}
plan tests => $tests;

foreach my $name (sort keys %yaml) {
  my $file = $yaml{$name};
  my $yaml = YAML::LoadFile($file);
  ok($yaml, $name.' - YAML');
  my $syck = YAML::Syck::LoadFile($file);
  ok($syck, $name.' - YAML::SYCK');
  is_deeply($syck, $yaml, $name.' - YAML::Syck should match YAML');
}
