package xPL::X10;

=head1 NAME

xPL::X10 - Perl extension for xPL X10 Encoding/Decoding

=head1 SYNOPSIS

  use xPL::X10;

  my $rfcode = xPL::X10::to_rf(house => 'a', unit => '1', command => 'on');

  my $res = xPL::X10::from_rf($rfcode);

=head1 DESCRIPTION

This is a module for handling the encoding/decoding of X10 messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision$/[1];

my $i = 0;
my %house_to_byte =
  map { $_ => $i++ } ('m', 'n', 'o', 'p', 'c', 'd', 'a', 'b',
                      'e', 'f', 'g', 'h', 'k', 'l', 'i', 'j');
my %byte_to_house = reverse %house_to_byte;

$i = 1;
my %bytes_to_unit =
  map { $_ => $i++ } ( 0x00, 0x10, 0x08, 0x18, 0x40, 0x50, 0x48, 0x58 );
my %unit_to_bytes = reverse %bytes_to_unit;
my $unit_mask= 0x58;

my %command_to_byte =
  (
   'dim' => 0x98,
   'bright' => 0x88,
   'all_lights_on' => 0x90,
   'all_lights_off' => 0x80,
   'on' => 0x0,
   'off' => 0x20,
  );
my %byte_to_command = reverse %command_to_byte;

=head2 C<to_rf( %parameter_hash )>

Takes a parameter hash describing an X10 command returns an array
reference of bytes containing the command in RF encoded form.

=cut

sub to_rf {
  my %p = @_;
  my @bytes = ( 0, 0, 0, 0 );
  $bytes[2] |= $command_to_byte{lc $p{command}};
  $bytes[0] |= ($house_to_byte{lc $p{house}})<<4;
  unless ($bytes[2]&0x80) {
    if ($p{unit} > 8) {
      $p{unit} -= 8;
      $bytes[0] |= 0x4;
    }
    $bytes[2] |= $unit_to_bytes{$p{unit}};
  }
  $bytes[1] = $bytes[0]^0xff;
  $bytes[3] = $bytes[2]^0xff;
  return \@bytes;
}

=head2 C<from_rf( $bytes )>

Takes an array reference of bytes from an RF message and converts it
in to an hash reference with the details.

=cut

sub from_rf {
  my $bytes = shift;

  return unless (is_x10($bytes));
  my %r = ();
  my $mask = 0x98;
  unless ($bytes->[2]&0x80) {
    $r{unit} = $bytes_to_unit{$bytes->[2]&$unit_mask};
    $r{unit} += 8 if ($bytes->[0]&0x4);
    $mask = 0x20;
  }
  $r{house} = $byte_to_house{($bytes->[0]&0xf0)>>4};
  $r{command} = $byte_to_command{$bytes->[2]&$mask};
  return \%r;
}

=head2 C<is_x10( $bytes )>

Takes an array reference of bytes from an RF message and returns true
if it appears to be a valid X10 message.

=cut

sub is_x10 {
  my $bytes = shift;

  return unless (scalar @$bytes == 4);

  (($bytes->[2]^0xff) == $bytes->[3] &&
   ($bytes->[0]^0xff) == $bytes->[1] &&
   !($bytes->[2]&0x7));
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2007, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
