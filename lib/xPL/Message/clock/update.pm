package xPL::Message::clock::update;

# $Id$

=head1 NAME

xPL::Message::clock::update - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message::clock::update;

  my $msg = xPL::Message::clock::update

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use xPL::Message;
use POSIX qw/strftime/;

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
    name => 'time',
    validation => xPL::Validation->new(type => 'Pattern',
                                       pattern => '\d{14}'),
    die => 1,
    error => "It should be 14 digits of the form 'YYYYMMDDhhmmss'.",
    default => strftime("%Y%m%d%H%M%S", localtime(time)),
   },
  ]
}

=head2 C<default_message_type()>

This method returns the default message type for this xPL message
schema.  It returns 'xpl-stat' since this is the only unique message
type defined by this message schema.

=cut

sub default_message_type {
  my $self = shift;
  return "xpl-stat";
}

=head2 C<summary()>

This method returns a summary of the xPL message.

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary(@_)." - ".$self->time;
}


=head2 C<time( [ $new_time ] )>

This method returns the time string.  If the optional new value
argument is present, then this method updates the time string
with the new value before it returns.

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

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
