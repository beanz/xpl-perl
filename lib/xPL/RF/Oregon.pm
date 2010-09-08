package xPL::RF::Oregon;

=head1 NAME

xPL::RF::Oregon - Perl extension for decoding Oregon Scientific RF messages

=head1 SYNOPSIS

  use xPL::RF::Oregon;

=head1 DESCRIPTION

This is a module for decoding RF messages from Oregon Scientific
sensor devices.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Date::Parse qw/str2time/;
use xPL::Message;
use xPL::Utils qw/:all/;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

my %types =
  (
   type_length_key(0xfa28, 80) =>
   {
    part => 'THGR810', checksum => \&checksum2, method => 'common_temphydro',
   },
   type_length_key(0xfab8, 80) =>
   {
    part => 'WTGR800', checksum => \&checksum2, method => 'alt_temphydro',
   },
   type_length_key(0x1a99, 88) =>
   {
    part => 'WTGR800', checksum => \&checksum4, method => 'wtgr800_anemometer',
   },
   type_length_key(0x1a89, 88) =>
   {
    part => 'WGR800', checksum => \&checksum4, method => 'wtgr800_anemometer',
   },
   type_length_key(0xda78, 72) =>
   {
    part => 'UVN800', checksun => \&checksum7, method => 'uvn800',
   },
   type_length_key(0xea7c, 120) =>
   {
    part => 'UV138', checksum => \&checksum1, method => 'uv138',
   },
   type_length_key(0xea4c, 80) =>
   {
    part => 'THWR288A', checksum => \&checksum1, method => 'common_temp',
   },
   type_length_key(0xea4c, 68) =>
   {
    part => 'THN132N', checksum => \&checksum1, method => 'common_temp',
   },
   type_length_key(0x8aec, 104) => { part => 'RTGR328N', },
   type_length_key(0x9aec, 104) =>
   {
    part => 'RTGR328N', checksum => \&checksum3, method => 'rtgr328n_datetime',
   },
   type_length_key(0x9aea, 104) =>
   {
    part => 'RTGR328N', checksum => \&checksum3, method => 'rtgr328n_datetime',
   },
   type_length_key(0x1a2d, 80) =>
   {
    part => 'THGR228N', checksum => \&checksum2, method => 'common_temphydro',
   },
   type_length_key(0x1a3d, 80) =>
   {
    part => 'THGR918', checksum => \&checksum2, method => 'common_temphydro',
   },
   type_length_key(0x5a5d, 88) =>
   {
    part => 'BTHR918', checksum => \&checksum5,
    method => 'common_temphydrobaro',
   },
   type_length_key(0x5a6d, 96) =>
   {
    part => 'BTHR918N', checksum => \&checksum5, method => 'alt_temphydrobaro',
   },
   type_length_key(0x3a0d, 80) =>
   {
    part => 'WGR918',  checksum => \&checksum4, method => 'wgr918_anemometer',
   },
   type_length_key(0x3a0d, 88) =>
   {
    part => 'WGR918',  checksum => \&checksum4, method => 'wgr918_anemometer',
   },
   type_length_key(0x2a1d, 84) =>
   {
    part => 'RGR918', checksum => \&checksum6, method => 'common_rain',
   },
   type_length_key(0x0a4d, 80) =>
   {
    part => 'THR128', checksum => \&checksum2, method => 'common_temp',
   },
   #type_length_key(0x0a4d,80)=>{ part => 'THR138', method => 'common_temp', },

   type_length_key(0xca2c, 80) =>
   {
    part => 'THGR328N', checksum => \&checksum2, method => 'common_temphydro',
   },

   type_length_key(0xca2c, 120) =>
   {
    part => 'THGR328N', checksum => \&checksum2, method => 'common_temphydro',
   },

   # masked
   type_length_key(0x0acc, 80) =>
   {
    part => 'RTGR328N', checksum => \&checksum2, method => 'common_temphydro',
   },

   type_length_key(0x2a19, 92) =>
   {
    part => 'PCR800',
    checksum => \&checksum8,
    method => 'pcr800_rain',
   },

   # for testing
   type_length_key(0xfefe, 80) => { part => 'TEST' },
  );

my $DOT = q{.};

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported Oregon
Scientific sensors.  It returns a list reference containing xPL
messages corresponding to the sensor readings or undef if the message
is not recognized.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  return unless (scalar @$bytes >= 2);

  my $type = ($bytes->[0] << 8) + $bytes->[1];
  my $key = type_length_key($type, $bits);
  my $rec = $types{$key} || $types{$key&0xfffff};
  unless ($rec) {
    return;
  }

  my @nibbles = map { hex $_ } split //, unpack "H*", $message;
  my $checksum = $rec->{checksum};
  if ($checksum && !$checksum->($bytes, \@nibbles)) {
    return;
  }

  my $method = $rec->{method};
  unless ($method) {
    warn "Possible message from Oregon part \"", $rec->{part}, "\"\n";
    return;
  }
  $self->$method(lc $rec->{part}, $parent, $message, $bytes, $bits, \@nibbles);
}

=head1 DEVICE METHODS

=head2 C<uv138( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a message from a UV138 sensor.

=cut

sub uv138 {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  uv($parent, $bytes, $nibbles, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<uvn800( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a message from a UVN800 sensor.

=cut

sub uvn800 {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  uv2($parent, $bytes, $nibbles, $dev_str, \@res);
  percentage_battery($parent, $bytes, $nibbles, $dev_str, \@res);
  return \@res;
}

=head2 C<wgr918_anemometer( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a wind speed/direction message from a WGR918 sensor.

=cut

sub wgr918_anemometer {
  my ($self, $type, $parent, $message, $bytes, $bits, $nib) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $dir = $nib->[10]*100 + $nib->[11]*10 + $nib->[8];
  my $speed = $nib->[15]*10 + $nib->[12] + $nib->[13]/10;
  my $avspeed = $nib->[16]*10 + $nib->[17] + $nib->[14]/10;
  #print "WGR918: $device $dir $speed\n";
  my @res = ();
  push @res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'speed',
                               current => $speed,
                               units => 'mps',
                               average => $avspeed,
                              ]
                     ),
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'direction',
                               current => $dir,
                               units => 'degrees',
                              ]
                     );
  percentage_battery($parent, $bytes, $nib, $dev_str, \@res);
  return \@res;
}

=head2 C<wtgr800_anemometer( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a wind speed/direction message from a WTGR800 sensor.

=cut

sub wtgr800_anemometer {
  my ($self, $type, $parent, $message, $bytes, $bits, $nib) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $dir = $nib->[8] * 22.5;
  my $speed = $nib->[14]*10 + $nib->[12] + $nib->[13]/10;
  my $avspeed = $nib->[16]*10 + $nib->[17] + $nib->[14]/10;
  #print "WTGR800: $device $dir $speed\n";
  my @res = ();
  push @res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'speed',
                               current => $speed,
                               units => 'mps',
                               average => $avspeed,
                              ]
                     ),
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'direction',
                               current => $dir,
                              ]
                     );
  percentage_battery($parent, $bytes, $nib, $dev_str, \@res);
  return \@res;
}

=head2 C<alt_temphydro( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity message from a WTGR800 sensor.

=cut

sub alt_temphydro {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $nibbles, $dev_str, \@res);
  humidity($parent, $bytes, $nibbles, $dev_str, \@res);
  percentage_battery($parent, $bytes, $nibbles, $dev_str, \@res);
  return \@res;
}

=head2 C<alt_temphydrobaro( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a temperature/humidity/baro message from a BTHR918N sensor.

=cut

sub alt_temphydrobaro {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $nibbles, $dev_str, \@res);
  humidity($parent, $bytes, $nibbles, $dev_str, \@res);
  pressure($parent, $bytes, $dev_str, \@res, $nibbles->[18], 856);
  percentage_battery($parent, $bytes, $nibbles, $dev_str, \@res);
  return \@res;
}

=head2 C<rtgr328n_datetime( $parent, $message, $bytes, $bits, $nibbles )>

This method is called if the device type bytes indicate that the bytes
might contain a date/time message from a RTGR328n sensor.

=cut

sub rtgr328n_datetime {
  my ($self, $type, $parent, $message, $bytes, $bits, $nib) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my $time = $nib->[15].$nib->[12].$nib->[13].$nib->[10].$nib->[11].$nib->[8];
  my $day =
    [ 'Mon', 'Tues', 'Wednes',
      'Thur', 'Fri', 'Satur', 'Sun' ]->[($bytes->[9]&0x7)-1];
  my $date =
    2000+($nib->[21].$nib->[18]).sprintf("%02d",$nib->[16]).
      $nib->[17].$nib->[14];

  #print STDERR "datetime: $date $time $day\n";
  my @res = ();
  return [xPL::Message->new(
                            message_type => 'xpl-trig',
                            class => 'datetime.basic',
                            head => { source => $parent->source, },
                            body => [
                                     datetime => $date.$time,
                                     'date' => $date,
                                     'time' => $time,
                                     day => $day.'day',
                                     device => $dev_str,
                                    ]
                           )];
}

=head2 C<common_temp( $type, $parent, $message, $bytes, $bits, $nibbles )>

This method is a generic device method for devices that report
temperature in a particular manner.

=cut

sub common_temp {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $nibbles, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_temphydro( $type, $parent, $message, $bytes, $bits, $nibbles )>

This method is a generic device method for devices that report
temperature and humidity in a particular manner.

=cut

sub common_temphydro {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $nibbles, $dev_str, \@res);
  humidity($parent, $bytes, $nibbles, $dev_str, \@res);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_temphydrobaro( $type, $parent, $message, $bytes, $bits, $nibbles )>

This method is a generic device method for devices that report
temperature, humidity and barometric pressure in a particular manner.

=cut

sub common_temphydrobaro {
  my ($self, $type, $parent, $message, $bytes, $bits, $nibbles) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  temperature($parent, $bytes, $nibbles, $dev_str, \@res);
  humidity($parent, $bytes, $nibbles, $dev_str, \@res);
  pressure($parent, $bytes, $dev_str, \@res, $nibbles->[19]);
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<common_rain( $type, $parent, $message, $bytes, $bits, $nibbles )>

This method handles the rain measurements from an RGR918 rain gauge.

=cut

sub common_rain {
  my ($self, $type, $parent, $message, $bytes, $bits, $nib) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  my $rain = $nib->[10]*100 + $nib->[11]*10 + $nib->[8];
  my $train = $nib->[17]*1000 + $nib->[14]*100 + $nib->[15]*10 + $nib->[12];
  my $flip = $nib->[13];
  #print STDERR "$dev_str rain = $rain, total = $train, flip = $flip\n";
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'speed',
                               current => $rain,
                               units => 'mm/h',
                              ]
                     );
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'distance',
                               current => $train,
                               units => 'mm',
                              ]
                     );
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'count',
                               current => $flip,
                               units => 'flips',
                              ]
                     );
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head2 C<pcr800_rain( $type, $parent, $message, $bytes, $bits, $nibbles )>

This method handles the rain measurements from a PCR800 rain gauge.

=cut

sub pcr800_rain {
  my ($self, $type, $parent, $message, $bytes, $bits, $nib) = @_;

  my $device = sprintf "%02x", $bytes->[3];
  my $dev_str = $type.$DOT.$device;
  my @res = ();
  my $rain = $nib->[13]*10 + $nib->[10] + $nib->[11]/10 + $nib->[8]/100;
  $rain *= 25.4; # convert from inch/hr to mm/hr

  my $train = $nib->[19]*100 + $nib->[16]*10 + $nib->[17]
    + $nib->[14]/10 + $nib->[15]/100 + $nib->[12]/1000;
  $train *= 25.4; # convert from inch/hr to mm/hr
  #print STDERR "$dev_str rain = $rain, total = $train\n";
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'speed',
                               current => (sprintf "%.2f", $rain),
                               units => 'mm/h',
                              ]
                     );
  push @res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev_str,
                               type => 'distance',
                               current => (sprintf "%.2f", $train),
                               units => 'mm',
                              ]
                     );
  simple_battery($parent, $bytes, $dev_str, \@res);
  return \@res;
}

=head1 CHECKSUM METHODS

=head2 C<checksum1( $bytes, $nibbles )>

This method is a byte checksum of all nibbles of the first 6 bytes,
the low nibble of the 7th byte, minus 10 which should equal the byte
consisting of a high nibble taken from the low nibble of the 8th byte
plus the high nibble from the 7th byte.

=cut

sub checksum1 {
  my $c = $_[1]->[12] + ($_[1]->[15]<<4);
  my $s = ( ( new_nibble_sum(12, $_[1]) + $_[1]->[13] - 0xa) & 0xff);
  $s == $c;
}

=head2 C<checksum2( $bytes )>

This method is a byte checksum of all nibbles of the first 8 bytes
minus 10, which should equal the 9th byte.

=cut

sub checksum2 {
  $_[0]->[8] == ((new_nibble_sum(16,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum3( $bytes )>

This method is a byte checksum of all nibbles of the first 11 bytes
minus 10, which should equal the 12th byte.

=cut

sub checksum3 {
  $_[0]->[11] == ((new_nibble_sum(22,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum4( $bytes )>

This method is a byte checksum of all nibbles of the first 9 bytes
minus 10, which should equal the 10th byte.

=cut

sub checksum4 {
  $_[0]->[9] == ((new_nibble_sum(18,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum5( $bytes )>

This method is a byte checksum of all nibbles of the first 10 bytes
minus 10, which should equal the 11th byte.

=cut

sub checksum5 {
  $_[0]->[10] == ((new_nibble_sum(20,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum6( $bytes )>

This method is a byte checksum of all nibbles of the first 10 bytes
minus 10, which should equal the 11th byte.

=cut

sub checksum6 {
  $_[1]->[16]+($_[1]->[19]<<4) == ((new_nibble_sum(16,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum7( $bytes )>

This method is a byte checksum of all nibbles of the first 7 bytes,
minus 10 which should equal the byte
consisting of the 8th byte

=cut

sub checksum7 {
  $_[0]->[7] == ((new_nibble_sum(14,$_[1]) - 0xa) & 0xff);
}

=head2 C<checksum8( $bytes )>

This method is a byte checksum of all nibbles of the first 7 bytes,
minus 10 which should equal the byte consisting of the 8th byte

=cut

sub checksum8 {
  my $c = $_[1]->[18] + ($_[1]->[21]<<4);
  my $s = ( ( new_nibble_sum(18, $_[1]) - 0xa) & 0xff);
  $s == $c;
}

=head2 C<checksum_tester( $bytes )>

This method is a dummy checksum method that tries to guess the checksum
that is required.

=cut

sub checksum_tester {
  my $found;
  foreach my $sum (qw/checksum1 checksum2 checksum3 checksum4 checksum5
                      checksum6 checksum7 checksum8/) {
    no strict qw/refs/;
    if ($sum->(@_)) {
      print "Possible use of checksum, $sum\n";
      $found++;
    }
    use strict;
  }
  exit if ($found);
  for my $i (4..(scalar @{$_[0]})-2) {
    my $c = hi_nibble($_[0]->[$i]) + (lo_nibble($_[0]->[$i+1])<<4);
    my $s = ( ( nibble_sum($i, $_[0]) - 0xa) & 0xff);
    print $i, " c=",$c, " s=", $s, "\n";
    if ($s == $c) {
      print q{
    my $c = hi_nibble($_[0]->[}.$i.q{]) + (lo_nibble($_[0]->[}.($i+1).q{])<<4);
    my $s = ( ( nibble_sum(}.$i.q{, $_[0]) - 0xa) & 0xff);
    $s == $c;
};
      $found++;
    }
    $c = $_[0]->[$i+1];
    $s = ( ( nibble_sum($i+.5, $_[0]) - 0xa) & 0xff);
    if ($s == $c) {
      print q{
    my $c = $_[0]->[}.($i+1).q{];
    my $s = ( ( nibble_sum(}.($i+.5).q{, $_[0]) - 0xa) & 0xff);
    $s == $c;
};
      $found++;
    }
  }
  exit if ($found);
  die "Could not determine checksum\n";
}

my @uv_str =
  (
   qw/low low low/, # 0 - 2
   qw/medium medium medium/, # 3 - 5
   qw/high high/, # 6 - 7
   'very high', 'very high', 'very high', # 8 - 10
  );

=head1 UTILITY METHODS

=head2 C<uv_string( $uv_index )>

This method takes the UV Index and returns a suitable string.

=cut

sub uv_string {
  $uv_str[$_[0]] || 'dangerous';
}

=head1 SENSOR READING METHODS

=head2 C<uv( $parent, $bytes, $nibbles, $device, \@result)>

This method processes a UV Index reading.  It appends an xPL message
to the result array.

=cut

sub uv {
  my ($parent, $bytes, $nib, $dev, $res) = @_;
  my $uv =  $nib->[11]*10 + $nib->[8];
  my $risk = uv_string($uv);
  #printf STDERR "%s uv=%d risk=%s\n", $dev, $uv, $risk;
  push @$res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'uv',
                               current => $uv,
                               risk => $risk,
                              ]
                     );
  1;
}

=head2 C<uv2( $parent, $bytes, $nibbles, $device, \@result)>

This method processes a UV Index reading for UVN800 sensor type.  It
appends an xPL message to the result array.

=cut

sub uv2 {
  my ($parent, $bytes, $nib, $dev, $res) = @_;
  my $uv =  $nib->[8];
  my $risk = uv_string($uv);
  #printf STDERR "%s uv=%d risk=%s\n", $dev, $uv, $risk;
  push @$res,
    xPL::Message->new(
                      strict => 0,
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'uv',
                               current => $uv,
                               risk => $risk,
                              ]
                     );
  1;
}

=head2 C<temperature( $parent, $bytes, $nibbles, $device, \@result)>

This method processes a temperature reading.  It appends an xPL message
to the result array.

=cut

sub temperature {
  my ($parent, $bytes, $nib, $dev, $res) = @_;
  my $temp = $nib->[10]*10 + $nib->[11] + $nib->[8]/10;
  $temp *= -1 if ($bytes->[6]&0x8);
  #printf STDERR "%s temp=%.1f\n", $dev, $temp;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'temp',
                               current => $temp,
                              ]
                     );
  1;
}

=head2 C<humidity( $parent, $bytes, $nibbles, $device, \@result)>

This method processes a humidity reading.  It appends an xPL message
to the result array.

=cut

sub humidity {
  my ($parent, $bytes, $nib, $dev, $res) = @_;
  my $hum = $nib->[15]*10 + $nib->[12];
  my $hum_str = ['normal', 'comfortable', 'dry', 'wet']->[$bytes->[7]>>6];
  #printf STDERR "%s hum=%d%% %s\n", $dev, $hum, $hum_str;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'humidity',
                               current => $hum,
                               string => $hum_str,
                              ]
                     );
  1;
}

=head2 C<pressure( $parent, $bytes, $device, \@result, $forecast_nibble,
                   $offset )>

This method processes a pressure reading.  It appends an xPL message
to the result array.

=cut

sub pressure {
  my ($parent, $bytes, $dev, $res, $forecast_nibble, $offset) = @_;
  $offset = 795 unless ($offset);
  my $hpa = $bytes->[8]+$offset;
  my $forecast = { 0xc => 'sunny',
                   0x6 => 'partly',
                   0x2 => 'cloudy',
                   0x3 => 'rain',
                 }->{$forecast_nibble} || 'unknown';
  #printf STDERR "%s baro: %d %s\n", $dev, $hpa, $forecast;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'pressure',
                               current => $hpa,
                               units => 'hPa',
                               forecast => $forecast,
                              ]
                     );
  1;
}

=head2 C<simple_battery( $parent, $bytes, $device, \@result)>

This method processes a simple low battery reading.  It appends an xPL
message to the result array if the battery is low.

=cut

sub simple_battery {
  my ($parent, $bytes, $dev, $res) = @_;
  my $battery_low = $bytes->[4]&0x4;
  my $bat = $battery_low ? 10 : 90;
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'battery',
                               current => $bat,
                               units => '%',
                              ]
                     );
  $battery_low;
}

=head2 C<percentage_battery( $parent, $bytes, $nibbles, $device, \@result)>

This method processes a battery percentage charge reading.  It appends
an xPL message to the result array if the battery is low.

=cut

sub percentage_battery {
  my ($parent, $bytes, $nib, $dev, $res) = @_;
  my $bat = 100-10*$nib->[9];
  push @$res,
    xPL::Message->new(
                      message_type => 'xpl-trig',
                      class => 'sensor.basic',
                      head => { source => $parent->source, },
                      body => [
                               device => $dev,
                               type => 'battery',
                               current => $bat,
                               units => '%',
                              ]
                     );
  $bat < 20;
}

=head2 C<type_length_key( $type, $length )>

This function creates a simple key from a device type and message
length (in bits).  It is used to as the index for the parts table.

=cut

sub type_length_key {
  ($_[0] << 8) + $_[1]
}

1;
__END__

=head1 EXPORT

None by default.

=head1 THANKS

Special thanks to RFXCOM, L<http://www.rfxcom.com/>, for their
excellent documentation and for giving me permission to use it to help
me write this code.  I own a number of their products and highly
recommend them.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
