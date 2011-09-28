package xPL::Timer;

=head1 NAME

xPL::Timer - Perl extension for xPL timer base class

=head1 SYNOPSIS

  use xPL::Timer;

  my $timer = xPL::Timer->new(type => 'simple', timeout => 30);

=head1 DESCRIPTION

This module creates an xPL timer abstraction.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Validation;

use xPL::Base qw/simple_tokenizer/;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our %modules = ();

=head2 C<new(%parameter_hash)>

The constructor creates a new xPL::Timer object.  The constructor
takes a parameter hash as arguments.  The hash should contain a 'type'
parameter with a value of 'simple', 'cron', 'sunset' and 'sunrise'.
Otherwise the 'simple' type is assumed.  The remaining values are
specific to the different timer types as described in the
documentation for the C<init> methods of the Timer sub-classes.

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my %p = @_;
  exists $p{type} or  $p{type} = 'simple';

  my $type = $p{type};
  my $module = $pkg.'::'.(lc $type);

  unless (exists $modules{$module}) {
    eval "require $module;";
    if ($EVAL_ERROR) {
      $pkg->argh("Failed to load $module: ".$EVAL_ERROR);
    } else {
      import $module;
      $modules{$module} = $module;
    }
  }
  $module = $modules{$module};

  my $self = {};
  bless $self, $module;

  $self->verbose($p{verbose}||0);

  $self->{_type} = $type;

  exists $p{tz} or $p{tz} = $ENV{TZ} || 'Europe/London';

  $self->init(\%p);

  return $self;
}

=head2 C<new_from_string( $specification_string )>

This is a constructor that takes the string of an xPL timer and
constructs an xPL::Timer object from it.

=cut

sub new_from_string {
  my $pkg = shift;
  my $timeout = shift;

  if ($timeout =~ /^-?[0-9\.]+(?:[eE]-?[0-9]+)?$/) {
    return $pkg->new(type => 'simple', timeout => $timeout);
  } elsif ($timeout =~ /^(\w+) (.*)$/i) {
    return $pkg->new(type => $1, simple_tokenizer($2));
  }
  return $pkg->new(type => $timeout);
}

1;
__END__

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2006, 2008 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
