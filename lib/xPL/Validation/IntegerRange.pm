package xPL::Validation::IntegerRange;

# $Id$

=head1 NAME

xPL::Validation::IntegerRange - Perl extension for xPL Validation integer range

=head1 SYNOPSIS

  # this class is not expected to be used directly

  use xPL::Validation;

  my $validation = xPL::Validation->new(type => 'IntegerRange');

=head1 DESCRIPTION

This module creates an xPL validation which is used to validate fields
of xPL messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;

use xPL::Validation;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Validation);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<init(\%parameter_hash)>

The constructor creates a new xPL::Validation::IntegerRange object.
The constructor takes a parameter hash as arguments.  Common
parameters are described in L<xPL::Validation>.  This validator type
has the following additional parameters:

=over 4

=item min

  The minimum valid value.  (Default: none)

=item max

  The maximum valid value.  (Default: none)

=back

One of the C<min> or C<max> parameters should be specified or this
class is simply the Integer validation with a performance overhead.

It returns a blessed reference when successful or undef otherwise.

=cut

sub init {
  $_[0]->{_min} = $_[1]->{min};
  $_[0]->{_max} = $_[1]->{max};
  $_[0];
}

=head2 C<singleton( )>

This method returns 0 because this validation has some parameters.

=cut

sub singleton {
  0;
}

=head2 C<summary()>

=cut

sub summary {
  $_[0]->SUPER::summary().
    " min=".(defined $_[0]->{_min} ? $_[0]->{_min} : "none").
    " max=".(defined $_[0]->{_max} ? $_[0]->{_max} : "none");
}

=head2 C<valid( $value )>

This method returns true if the value is valid.

=cut

sub valid {
  defined $_[1] && $_[1] =~ qr/^-?\d+$/ &&
    (!defined $_[0]->{_min} or $_[1] >= $_[0]->{_min}) &&
    (!defined $_[0]->{_max} or $_[1] <= $_[0]->{_max});
}

=head2 C<error( )>

This method returns a suitable error string for the validation.

=cut

sub error {
  if (defined $_[0]->{_min}) {
    if (defined $_[0]->{_max}) {
      return 'It should be an integer between '.
        $_[0]->{_min}.' and '.$_[0]->{_max}.'.';
    } else {
      return 'It should be an integer greater than or equal to '.
        $_[0]->{_min}.'.';
    }
  } elsif (defined $_[0]->{_max}) {
    return 'It should be an integer less than or equal to '.$_[0]->{_max}.'.';
  } else {
    # this should just be an Integer validation!
    return 'It should be an integer.';
  }
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005, 2007 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
