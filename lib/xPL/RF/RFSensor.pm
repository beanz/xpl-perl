package xPL::RF::RFSensor;

# $Id: RFSensor.pm 220 2007-05-09 20:55:44Z beanz $

=head1 NAME

xPL::RF::RFSensor - Perl extension for an xPL RF Class

=head1 SYNOPSIS

  use xPL::RF::RFSensor;

=head1 DESCRIPTION

This is a module contains a module for handling the decoding of RF
messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Message;
use Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $SVNVERSION = qw/$Revision: 220 $/[1];

=head2 C<parse( $parent, $message, $bytes, $bits )>

TODO: POD

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 32 or return;
  (($bytes->[0]^0xf0) == $bytes->[1]) or return;
  checksum($bytes) or return;
  my $device = sprintf("rfsensor%02x%02x", $bytes->[0], $bytes->[1]);
  my $flag = $bytes->[3]&0x10;
  if ($flag) {
    # not implemented yet
  } else {
    if (($bytes->[0]&0x3) == 0) {
      # temp
      my $temp = $bytes->[2] + ($bytes->[3]&0x80 ? .5 : 0);
      return [xPL::Message->new(
                                strict => 0,
                                message_type => 'xpl-trig',
                                class => 'sensor.basic',
                                head => { source => $parent->source, },
                                body => {
                                         device => $device,
                                         type => 'temp',
                                         current => $temp,
                                        }
                               )];

    } else {
      print STDERR "Unsupported RFSensor\n";
      # not implemented yet
    }
  }
  return;
}

sub lo_nibble {
  $_[0]&0xf;
}
sub hi_nibble {
  ($_[0]&0xf0)>>4;
}

sub checksum {
  my $c = lo_nibble($_[0]->[3]);
  my $s = 0;
  foreach (0..2) {
    $s += lo_nibble($_[0]->[$_]);
    $s += hi_nibble($_[0]->[$_]);
  }
  $s += hi_nibble($_[0]->[3]);
  $s ^= 0xf;
  $s &= 0xf;
  return $s == $c;
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

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
