package xPL::Validation::Set;

# $Id$

=head1 NAME

xPL::Validation::Set - Perl extension for xPL Validation set class

=head1 SYNOPSIS

  # this class is not expected to be used directly

  use xPL::Validation;

  my $validation = xPL::Validation->new(type => 'Set');

=head1 DESCRIPTION

This module creates an xPL validation which is used to validate fields
of xPL messages.  This validator is case insensitive.

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

The constructor creates a new xPL::Validation::Set object.
The constructor takes a parameter hash as arguments.  Common
parameters are described in L<xPL::Validation>.  This validator type
has the following additional parameters:

=over 4

=item set

  An array reference of the set of valid values.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub init {
  my $self = shift;
  my $p = shift;

  exists $p->{set} or $self->argh(q{requires 'set' parameter});
  my $set = $self->{_set} = $p->{set};
  $self->{_set_str} = join(", ", map { q{'}.$_.q{'} } @{$set});
  $self->{_set_str} =~ s/, ([^,]+)$/ or $1/;
  $self->{_set_short_str} =
    ((length $self->{_set_str}) < 40 ?
     $self->{_set_str} :
     (substr $self->{_set_str}, 0, 37).'...');
  $self->{_set_map} = { map { (lc $_) => 1 } @{$set} };
  return $self;
}

=head2 C<summary()>

=cut

sub summary {
  my $self = shift;
  return $self->SUPER::summary()." set=".$self->{_set_short_str};
}

=head2 C<valid( $value )>

This method returns true if the value is valid.

=cut

sub valid {
  my $self = shift;
  return defined $_[0] && exists $self->{_set_map}->{lc $_[0]};
}

=head2 C<error( )>

This method returns a suitable error string for the validation.

=cut

sub error {
  my $self = shift;
  return 'It should be one of '.$self->{_set_str}.'.';
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

Copyright (C) 2005 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
