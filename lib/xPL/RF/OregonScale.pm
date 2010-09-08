package xPL::RF::OregonScale;

=head1 NAME

xPL::RF::OregonScale - Perl extension for Oregon Scientific scale RF messages

=head1 SYNOPSIS

  use xPL::RF::OregonScale;

=head1 DESCRIPTION

This is a module for decoding RF messages from Oregon Scientific scales.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use xPL::Utils qw/:all/;
use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision: 407 $/[1];

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method is called via the main C<xPL::RF> decode loop and it
determines whether the bytes match the format of any supported Oregon
Scientific scales.  It returns a list reference containing xPL
messages corresponding to the scale readings or undef if the message
is not recognized.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  if ($bits == 64 && lo_nibble($bytes->[0]) == 3) {
    return parse_gr101($self, $parent, $message, $bytes, $bits);
  }
  return unless (scalar @$bytes == 7);
  return unless (($bytes->[0]&0xf0) == ($bytes->[5]&0xf0) &&
                 ($bytes->[1]&0xf) == ($bytes->[6]&0xf));
  my $weight =
    sprintf "%x%02x%x", $bytes->[5]&0x1, $bytes->[4], hi_nibble($bytes->[3]);
  return unless ($weight =~ /^\d+$/);
  $weight /= 10;
  my $dev_str = sprintf 'bwr102.%02x', hi_nibble($bytes->[1]);
  my $unknown = sprintf "%x%x", lo_nibble($bytes->[3]), hi_nibble($bytes->[2]);
  return [{
           class => 'sensor.basic',
           body => [
                    device => $dev_str,
                    type => 'weight',
                    current => $weight,
                    unknown => $unknown,
                   ],
          }];
}

=head2 C<parse_gr101( $parent, $message, $bytes, $bits )>

This method is a helper for the main L<parse> method that handles the
GR101 scales only.  Parameters and return values are the same as the
L<parse> method.

=cut

sub parse_gr101 {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  my $weight =
    (lo_nibble($bytes->[4])<<12) + ($bytes->[3]<<4) + ($bytes->[2]>>4);
  $weight = sprintf "%.1f", $weight/400.8;
  my $dev_str = sprintf 'gr101.%02x', $bytes->[1];
  return [{
           class => 'sensor.basic',
           body => [
                    device => $dev_str,
                    type => 'weight',
                    current => $weight,
                   ],
          }];
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

Copyright (C) 2008, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
