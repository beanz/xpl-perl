package xPL::RF::Electrisave;

# $Id$

=head1 NAME

xPL::RF::Electrisave - Perl extension for decoding electrisave RF messages

=head1 SYNOPSIS

  use xPL::RF::Electrisave;

=head1 DESCRIPTION

This is a module for decoding RF messages from Electrisave,
Cent-a-meter and/or OWL electricity usage devices.

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

=head2 C<parse( $parent, $message, $bytes, $bits )>

This method attempts to recognize and parse RF messages from
Electrisave/Cent-a-meter/OWL devices.  If a suitable message is
identified, a reference to a list of xPL::Message objects is returned
for each reading.  If the message is not recognized, undef is
returned.

=cut

sub parse {
  my $self = shift;
  my $parent = shift;
  my $message = shift;
  my $bytes = shift;
  my $bits = shift;

  $bits == 120 or return;

  ($bytes->[0]==0xea && $bytes->[9]==0xff && $bytes->[10]==0x5f) or return;

  my $device = sprintf "%02x", $bytes->[2];
  my @ct = ();
  $ct[1] = ( (($bytes->[3]     )   )+(($bytes->[4]&0x3 )<<8) ) / 10;
  $ct[2] = ( (($bytes->[4]&0xFC)>>2)+(($bytes->[5]&0xF )<<6) ) / 10;
  $ct[3] = ( (($bytes->[5]&0xF0)>>4)+(($bytes->[6]&0x3F)<<4) ) / 10;
  $ct[0] = $ct[1] + $ct[2] + $ct[3];
  my @msgs = ();
  foreach my $index (0..3) {
    my $dev = $device.($index ? '.'.$index : '');
    #my $kwh = ($ct[$index]*240)/1000;
    #printf "electrisave d=%s kwh=%.2f\n", $dev, $kwh;
    push @msgs,
      xPL::Message->new(
                        message_type => 'xpl-trig',
                        class => 'sensor.basic',
                        head => { source => $parent->source, },
                        body => {
                                 device => 'electrisave.'.$dev,
                                 type => 'current',
                                 current => $ct[$index],
                                }
                       );
  }
  return \@msgs;
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

Copyright (C) 2007, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
