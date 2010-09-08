#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

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

my %depends =
  (
   'xPL::RF::Oregon' => ['Date::Parse'],
   'xPL::Timer::cron' => ['DateTime::Event::Cron'],
   'xPL::Timer::sunrise' => ['DateTime::Event::Sunrise'],
   'xPL::Timer::sunset' => ['DateTime::Event::Sunrise'],
   'xPL::Timer::recurrence' => ['DateTime::Event::Recurrence'],
   'xPL::Gtk2Client' => ['Gtk2'],
   'SMS::Send::CSoft' => ['SMS::Send'],
   'SMS::Send::SMSDiscount' => ['SMS::Send'],
   'xPL::Dock::Bluetooth' => ['Net::Bluetooth'],
   'xPL::Dock::FDNotify' => ['Net::DBus'],
   'xPL::Dock::XOSD' => ['X::Osd'],
   'xPL::Dock::Jabber' => ['Net::XMPP'],
   'xPL::Dock::TCPHelp' => ['Digest::HMAC'],
  );

my %has;
foreach my $m (@modules) {
 SKIP: {
    skip 'no database defined, see xPL::SQL', 1
      if ($m eq 'xPL::SQL' && !exists $ENV{'XPL_DB_CONFIG'});

    my $missing;
    foreach my $dep (@{$depends{$m}||[]}) {
      next if (has_module(\%has, $dep));
      $missing = $dep;
      last;
    }
    skip $missing.' not available', 1 if (defined $missing);

    require_ok($m);
  }
}

sub has_module {
  my ($cache, $module) = @_;
  return $cache->{$module} if (exists $cache->{$module});
  eval " require $module ";
  $cache->{$module} = !$@;
}

