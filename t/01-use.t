#!/usr/bin/perl -w
#
# Copyright (C) 2005, 2009 by Mark Hindess

use strict;
my @modules;

BEGIN {
  open my $fh, '<', 'MANIFEST' or die 'Open of MANIFEST failed: '.$!;
  while(<$fh>) {
    next if (!/^lib\/(.*)\.pm/);
    my $m = $1;
    $m =~ s!/!::!g;
    push @modules, $m;
  }
  close $fh;
  require Test::More;
  import Test::More tests => scalar @modules;
}

my %depends =
  (
   'xPL::RF::Oregon' => ['Date::Parse'],
   'xPL::Timer::cron' => ['DateTime::Event::Cron' ],
   'xPL::Timer::sunrise' => ['DateTime::Event::Sunrise'],
   'xPL::Timer::sunset' => ['DateTime::Event::Sunrise'],
   'xPL::Timer::recurrence' => ['DateTime::Event::Recurrence'],
   'xPL::Gtk2Client' => ['Gtk2'],
   'SMS::Send::CSoft' => ['SMS::Send'],
   'SMS::Send::SMSDiscount' => ['SMS::Send'],
   'xPL::Dock::Bluetooth' => ['Net::Bluetooth'],
   'xPL::Dock::CurrentCost' => ['AnyEvent::CurrentCost'],
   'xPL::Dock::FDNotify' => ['Net::DBus'],
   'xPL::Dock::GPower' => ['HTTP::Request'],
   'xPL::Dock::Jabber' => ['AnyEvent::XMPP', 'Authen::SASL'],
   'xPL::Dock::Notifo' => ['AnyEvent::WebService::Notifo'],
   'xPL::Dock::OWNet' => ['AnyEvent::OWNet'],
   'xPL::Dock::RFXComRX' => ['AnyEvent::RFXCOM::RX'],
   'xPL::Dock::RFXComTX' => ['AnyEvent::RFXCOM::TX'],
   'xPL::Dock::TCPHelp' => ['Digest::HMAC'],
   'xPL::Dock::W800' => ['AnyEvent::W800'],
   'xPL::Dock::XOSD' => ['X::Osd'],
  );

foreach my $m (@modules) {
 SKIP: {
    skip 'no database defined, see xPL::SQL', 1
      if ($m eq 'xPL::SQL' && !exists $ENV{'XPL_DB_CONFIG'});

    my $missing;
    foreach my $dep (@{$depends{$m}||[]}) {
      next if (in_inc_path($dep));
      $missing = $dep;
      last;
    }
    skip $missing.' not available', 1 if (defined $missing);

    require_ok($m);
  }
}

sub in_inc_path {
  my $mod = shift;
  $mod =~ s!::!/!g;
  $mod .= '.pm';
  eval { require $mod } or return;
  return 1;
}
