package xPL::Message::tts::basic;

# $Id$

=head1 NAME

xPL::Message::tts::basic - Perl class for xPL 'tts.basic' messages

=head1 SYNOPSIS

  use xPL::Message::tts::basic;

  my $msg = xPL::Message::tts::basic

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
    name => 'speech',
    validation => xPL::Validation->new(type => 'Any'),
    required => 1,
   },
   {
    name => 'volume',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => 0, max => 100),
    die => 1,
   },
   {
    name => 'speed',
    validation => xPL::Validation->new(type => 'IntegerRange',
                                       min => -10, max => 10),
    die => 1,
   },
   {
    name => 'voice',
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
  return $self->SUPER::summary(@_).' - '.$self->speech;
}

=head2 C<speech( [ $new_speech ] )>

This method returns the tts speech value.  If the optional new value
argument is present, then this method updates the tts speech attribute
with the new value before it returns.

=head2 C<volume( [ $new_volume ] )>

This method returns the tts volume value.  If the optional new value
argument is present, then this method updates the tts volume attribute
with the new value before it returns.  The volume should be an integer
in the range 0 to 100.

=head2 C<speed( [ $new_speed ] )>

This method returns the tts speed value.  If the optional new value
argument is present, then this method updates the tts speed attribute
with the new value before it returns.  The speed should be an integer
in the range -10 to 10.

=head2 C<voice( [ $new_voice ] )>

This method returns the tts voice value.  If the optional new value
argument is present, then this method updates the tts voice attribute
with the new value before it returns.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

Schema Definition:
   http://wiki.xplproject.org.uk/index.php/Schema_-_TTS.BASIC

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
