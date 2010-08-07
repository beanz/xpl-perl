package xPL::ConfigUnion;

=head1 NAME

xPL::ConfigUnion - Perl extension for xPL Config union

=head1 SYNOPSIS

  use xPL::Config;
  use xPL::ConfigUnion;

  my $config = xPL::ConfigUnion->new([xPL::Config->new($key1),
                                      xPL::Config->new($key2)]) or die;

=head1 DESCRIPTION

This module creates an xPL config which is the union of several other
xPL::Config item.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Carp;
use xPL::Config;

our @ISA = qw(xPL::Config);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(@configs)>

The constructor creates a new xPL::ConfigUnion object.  The object
will behave like an C<xPL::Config> object that is the union of all the
other C<xPL::Config> items.

It returns a blessed reference if the C<@config> list is non-empty or
undef otherwise.

=cut

sub new {
  my $pkg = shift;
  return unless (@_);
  my @configs = @_;
  bless \@configs, $pkg;
}

=head2 C<items()>

This method returns a list of the names of the configuration items
in the order in which they are define.

=cut

sub items {
  my ($self) = @_;
  my @order;
  foreach my $config (@$self) {
    push @order, $config->items;
  }
  return @order;
}

=head2 C<is_item($name)>

This method returns true if the given name is a valid item name.

=cut

sub is_item {
  my ($self, $name) = @_;
  foreach my $config (@$self) {
    return 1 if ($config->is_item($name))
  }
  return
}

=head2 C<is_item_required($name)>

This method returns true if the named item requires a value.  It
returns false if the item is optional.

=cut

sub is_item_required {
  my ($self, $name) = @_;
  foreach my $config (@$self) {
    return 1 if ($config->is_item_required($name))
  }
  return
}

=head2 C<max_item_values($name)>

This method returns the number of values the named item can have.  It
returns 1 if the item is not multi-valued.

=cut

sub max_item_values {
  my ($self, $name) = @_;
  foreach my $config (@$self) {
    my $n = $config->max_item_values($name);
    return $n if ($n);
  }
  return 1
}

=head2 C<item_type($name)>

This method returns the type of the named item.

=cut

sub item_type {
  my ($self, $name) = @_;
  foreach my $config (@$self) {
    my $type = $config->item_type($name);
    return $type if ($type ne 'option');
  }
  return 'option'
}

=head2 C<get_item($name)>

This method returns the value of the named item.  For multi-valued
items it will always be an array reference.

=cut

sub get_item {
  my ($self, $name) = @_;
  foreach my $config (@$self) {
    my $v = $config->get_item($name);
    return $v if (defined $v);
  }
  return
}

=head2 C<set_item($name, $value)>

This method sets the value of the named item.  For multi-valued items
it should be an array reference.

=cut

sub set_item {
  my ($self, $name, $value) = @_;
  foreach my $config (@$self) {
    next unless ($config->is_item($name));
    $config->set_item($name, $value);
  }
  return $value
}

=head2 C<update_item($name)>

This method updates the value of the named item.  It returns one of:

=over 4

=item set

  If the item is updated replacing an undefined value.

=item changed

  If the item is updated replacing a previously defined value.

=item undef

  If the item is not an item or the previous value is equal
  to the new value.

=back

=cut

sub update_item {
  my ($self, $name, $value) = @_;
  my $result;
  foreach my $config (@$self) {
    my $res = $config->update_item($name, $value);
    $result = $res if (defined $res and
                       (!defined $result || $result eq 'set'));
  }
  return $result
}

=head2 C<items_requiring_config()>

This method returns a list of the items that are mandatory and which
are currently unconfigured.

=cut

sub items_requiring_config {
  my ($self) = @_;
  my @needed;
  foreach my $config (@$self) {
    push @needed, $config->items_requiring_config;
  }
  return @needed;
}

=head2 C<config_types()>

This method returns a hash reference contain keys for each element
where the values are the types of the items suffixed with '[NN]' for
multi-valued items where 'NN' is the maximum number of values.

=cut

sub config_types {
  my ($self) = @_;
  my %body;
  foreach my $config (@$self) {
    my $b = $config->config_types();
    foreach (qw/config reconf option/) {
      push @{$body{$_}}, @{$b->{$_}} if (exists $b->{$_});
    }
  }
  return \%body;
}

=head2 C<config_current()>

This method returns a hash reference contain keys for each element
where the values are values of the items.

=cut

sub config_current {
  my ($self) = @_;
  my %body;
  foreach my $config (@$self) {
    my $b = $config->config_current();
    foreach my $k (keys %$b) {
      $body{$k} = $b->{$k};
    }
  }
  return \%body;
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

Copyright (C) 2009, 2010 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
