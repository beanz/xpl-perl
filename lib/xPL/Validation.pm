package xPL::Validation;

=head1 NAME

xPL::Validation - Perl extension for xPL Validation base class

=head1 SYNOPSIS

  use xPL::Validation;

  my $validation = xPL::Validation->new(type => 'Integer');

  $validation->valid(10) or
    die "Value 10 is invalid.\n".$validation->error();

  $validation->valid("xxx") or
    die "Value 10 is invalid.\n".$validation->error();

  $validation = xPL::Validation->new(type => 'PositiveInteger');

  $validation->valid(-10) or
    die "Value -10 is invalid.\n".$validation->error();

  $validation = xPL::Validation->new(type => 'IntegerRange',
                                     min => 5, max => 30);

  $validation->valid(15) or
    die "Value 15 is invalid.\n".$validation->error();


=head1 DESCRIPTION

This module creates an xPL validation which is used to validate fields
of xPL messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Validation::Any;

use xPL::Base;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our %modules = ();
our $DOUBLE_COLON = q{::};

__PACKAGE__->make_readonly_accessor(qw/type/);

=head2 C<new(%parameter_hash)>

The constructor creates a new xPL::Validation object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item type

  The validation type.  Valid values are 'integer', 'positive-integer',
  'integer-range', etc.

=back

Other parameters are specific to the validation type.

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my %p = @_;

  my $type = $p{type};
  defined $type or $pkg->argh(q{requires 'type' parameter});

  my $module = $pkg.$DOUBLE_COLON.$type;
  unless (exists $modules{$module}) {
    eval "require $module";
    if ($EVAL_ERROR) {
      # default for unknown validation type - accepts all values
      $modules{$module} = $pkg.'::Any';
      if (exists $ENV{XPL_VALIDATION_WARN}) {
        warn "Failed to load $module: ".$EVAL_ERROR;
      }
    } else {
      import $module;
      $modules{$module} = $module;
    }
  }
  $module = $modules{$module};

  if (ref($module)) {
    # return previously instantiated singleton
    return $module;
  }

  my $self = {};
  bless $self, $module;
  $self->{_verbose} = $p{verbose}||0;
  $self->{_type} = $type;
  $self->init(\%p);
  $modules{$module} = $self if ($self->singleton);

  $self;
}

=head2 C<init( $parameter_hash_ref )>

This method processes the parameters passed to the validation.  It
does nothing in this base class, but it should be overridden by
validation classes that have parameters.

=cut

sub init {
  $_[0];
}

=head2 C<singleton( )>

This method returns 1 if the validation can be a singleton.  This
is the case for validations that have no parameters - such as
Integer, Any, etc. - but not for others - such as IntegerRange,
Pattern, etc.

=cut

sub singleton {
  1
}

=head2 C<summary()>

This method returns a string containing a summary of the xPL
validation.  It is intended for use when logging and debugging.  This
method is intended to be overridden so that specific validations can
append brief relevant data to the common components of the summary.

=cut

sub summary {
  $_[0]->type;
}

=head2 C<valid( $value )>

This method returns true if the value is valid.

=cut

sub valid {
  1;
}

=head2 C<error( )>

This method returns a suitable error string for the validation.

=cut

sub error {
  'It can be any value.'; # This wont get used much!
}

=head2 C<type( )>

This method returns the validation type.

=cut

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
