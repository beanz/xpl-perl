package xPL::Message::sensor::humidity;

# $Id: humidity.pm 85 2006-01-14 07:53:24Z beanz $

=head1 NAME

xPL::Message::sensor::humidity - Perl extension for xPL sensor humidity message

=head1 SYNOPSIS

  use xPL::Message::sensor::humidity;

  my $msg = xPL::Message::sensor::humidity

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::Message::sensor::basic;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Message::sensor::basic);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision: 85 $/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'device',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'type',
    validation => xPL::Validation->new(type => 'Set',
                                       set => [qw/humidity/]),
    required => 1,
   },
   {
    name => 'current',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'lowest',
    validation => xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'highest',
    validation => xPL::Validation->new(type => 'Any'),
   },
  ]
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=head2 C<device( [ $new_device ] )>

This method returns the name of the device.  If the optional new value
argument is present, then this method updates the device name with the
new value before it returns.


=head2 C<type( [ $new_type ] )>

This method returns the device type.  If the optional new value
argument is present, then this method updates the device type with the
new value before it returns.


=head2 C<current( [ $new_current ] )>

This method returns the current value of the sensor.  If the optional
new value argument is present, then this method updates the current
sensor value with the new value before it returns.

=head2 C<lowest( [ $new_lowest ] )>

This method returns the lowest value recorded by the sensor if it is
defined.  If the optional new value argument is present, then this
method updates the lowest value with the new value before it returns.

=head2 C<highest( [ $new_highest ] )>

This method returns the highest value recorded by the sensor if it is
defined.  If the optional new value argument is present, then this
method updates the highest value with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_SENSOR.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
