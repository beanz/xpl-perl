package xPL::Message::control::basic;

# $Id$

=head1 NAME

xPL::Message::control::basic - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message::control::basic;

  my $msg = xPL::Message::control::basic

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::Message;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Message);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

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
                                       set =>
                                         [qw/balance flag infrared input
                                             macro mute output variable
                                             periodic scheduled slider
                                             timer/]),
    required => 1,
   },
   {
    name => 'current',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'data1',
    validation => xPL::Validation->new(type => 'Any'),
   },
   {
    name => 'name',
    validation => xPL::Validation->new(type => 'Any'),
   },
  ]
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-cmnd' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  return "xpl-cmnd";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_).' - '.$self->device.'='.$self->current;
}

=head2 C<device( [ $new_device ] )>

This method returns the name of the device.  If the optional new value
argument is present, then this method updates the device name with the
new value before it returns.


=head2 C<type( [ $new_type ] )>

This method returns the device type.  If the optional new value
argument is present, then this method updates the device type with the
new value before it returns.


=head2 C<current( [ $new_current ] )>

This method returns the current value of the control.  If the optional
new value argument is present, then this method updates the current
control value with the new value before it returns.

=head2 C<data1( [ $new_data1 ] )>

This method returns the optional data1 value for the control if it is
defined.  If the optional new value argument is present, then this
method updates the data1 value with the new value before it returns.

=head2 C<name( [ $new_name ] )>

This method returns the name element of the message if it is
defined.  If the optional new value argument is present, then this
method updates the name value with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_CONTROL.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
