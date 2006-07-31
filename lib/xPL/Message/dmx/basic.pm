package xPL::Message::dmx::basic;

# $Id: basic.pm 151 2006-05-27 10:53:39Z beanz $

=head1 NAME

xPL::Message::dmx::basic - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message::dmx::basic;

  my $msg = xPL::Message::dmx::basic

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
our $VERSION = qw/$Revision: 151 $/[1];

=head2 C<field_spec()>

This method returns the field specification for the body of this
message type.

=cut

sub field_spec {
  [
   {
    name => 'base',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'type',
    validation => xPL::Validation->new(type => 'Set',
                                       set =>
                                         [qw/set/]),
    required => 1,
   },
   {
    name => 'value',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
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
  return $self->SUPER::summary(@_).' - '.
    $self->type.':'.$self->base.'='.$self->value;
}

=head2 C<base( [ $new_base ] )>

This method returns the DMX base address.  If the optional new value
argument is present, then this method updates the base address with
the new value before it returns.  The address should either be a
single number between 1 and 512, or a such a number followed by 'x'
and then a second number, where the second number is the number of
times to repeat the values.  For instance, a message containing a base
address of 1x2 and a value of 0xff0000 would set the values for the
addresses from 1 to 6 to 0xff,0x00, 0x00, 0xff, 0x00, and 0x00
respectively.


=head2 C<type( [ $new_type ] )>

This method returns the dmx command type.  If the optional new value
argument is present, then this method updates the dmx command type
with the new value before it returns.  Currently, 'set' is the only
supported DMX command type.


=head2 C<value( [ $new_value ] )>

This method returns the value.  If the optional new value argument is
present, then this method updates the current value with the new value
before it returns.  The new value should be either a number from 0 to
255 or a hex string prefixed by '0x'.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
