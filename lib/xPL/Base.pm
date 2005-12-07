package xPL::Base;

# $Id: Base.pm,v 1.8 2005/12/06 17:27:11 beanz Exp $

=head1 NAME

xPL::Base - Perl extension for an xPL Base Class

=head1 SYNOPSIS

  use xPL::Base;
  our @ISA = qw/xPL::Base/;

=head1 DESCRIPTION

This is a module for a common base class for the xPL modules.  It
contains a number of helper methods.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;

use Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';
our $CVSVERSION = qw/$Revision: 1.8 $/[1];

=head1 COLLECTION STRUCTURE API

A number of the classes maintain collections of items.  For instance,
the L<xPL::Hub> maintains a collection of clientsa and the
L<xPL::Listener> maintains a collection for timers and another for
callbacks for xPL Messages.  These methods provide the basic interface
for those collections.

=head2 C<init_items($type)>

This method must be called before a collection is used.  It
is typically called from the constructor.

=cut

sub init_items {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} and
    $self->argh("BUG: item type, $type, already initialized");
  $self->{_col}->{$type} = {};
  return 1;
}

=head2 C<add_item($type, $id, \%attributes)>

This method is used by L<add_input>, L<add_timer>, etc. to add
items to their respective collections.

=cut

sub add_item {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} or
    $self->argh("BUG: item type, $type, invalid");
  my $id = shift or $self->argh('BUG: item id missing');
  my $attribs = shift or $self->argh('BUG: item attribs missing');
  if ($self->exists_item($type, $id)) {
    $self->argh("$type item '$id' already registered");
  }
  return $self->{_col}->{$type}->{$id} = $attribs;
}

=head2 C<exists_item($type, $id)>

This method is used by L<exists_input>, L<exists_timer>, etc. to check
for existence of items in their respective collections.

=cut

sub exists_item {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} or
    $self->argh("BUG: item type, $type, invalid");
  my $id = shift or $self->argh('BUG: item id missing');
  return exists $self->{_col}->{$type}->{$id};
}

=head2 C<remove_item($type, $id)>

This method is used by L<remove_input>, L<remove_timer>, etc. to remove
items from their respective collections.

=cut

sub remove_item {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} or
    $self->argh("BUG: item type, $type, invalid");
  my $id = shift or $self->argh('BUG: item id missing');
  unless ($self->exists_item($type, $id)) {
    return $self->ouch("$type item '$id' not registered");
  }

  delete $self->{_col}->{$type}->{$id};
  return 1;
}

=head2 C<item_attrib($type, $id, $attrib)>

This method is used by L<input_attrib>, L<timer_attrib>, etc. to query
the value of attributes of registered items in their respective
collections.

=cut

sub item_attrib {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} or
    $self->argh("BUG: item type, $type, invalid");
  my $id = shift or $self->argh('BUG: item id missing');
  unless ($self->exists_item($type, $id)) {
    return $self->ouch("$type item '$id' not registered");
  }
  my $key = shift or $self->argh('missing key');
  if (@_) {
    $self->{_col}->{$type}->{$id}->{$key} = $_[0];
  }
  return $self->{_col}->{$type}->{$id}->{$key};
}

=head2 C<items($type)>

This method is used by L<timers>, L<inputs>, etc. to query
the ids of registered items in their respective collections.

=cut

sub items {
  my $self = shift;
  my $type = shift or $self->argh('BUG: item type missing');
  exists $self->{_col}->{$type} or
    $self->argh("BUG: item type, $type, invalid");
  return keys %{$self->{_col}->{$type}};
}

=head2 C<add_callback_item($type, $id, \%attributes)>

This method is a wrapper around L<add_item> to handle some
functionality for adding items that happen to be callbacks - which
most of the items used internally by this module are at the moment.

=cut

sub add_callback_item {
  my $self = shift;
  my $attribs = $self->add_item(@_);
  exists $attribs->{callback} or $attribs->{callback} = sub { 1; };
  exists $attribs->{arguments} or $attribs->{arguments} = [];
  $attribs->{callback_count} = 0;
  return $attribs;
}

=head1 METHOD MAKER METHODS

=head2 C<make_collection(collection1 => [attrib1, attrib2]);

This method creates some wrapper methods for a collection.  For instance,
if called as:

  __PACKAGE__->make_collection_method('client' => ['source', 'identity']);

it creates a set of methods called "add_client", "exists_client", ...
corresponding to the collection methods above.  It also creates methods
"client_source" and "client_identity" to retrieve client item attributes.

=cut

sub make_collection {
  my $pkg = shift;
  my %collections = @_;
  foreach my $collection_name (keys %collections) {
    foreach my $method (qw/add_X exists_X remove_X Xs X_attrib init_Xs/) {
      $pkg->make_collection_method($collection_name, $method);
    }
    foreach my $attr (@{$collections{$collection_name}}) {
      $pkg->make_item_attribute_method($collection_name, $attr);
    }
  }
  return 1;
}

=head2 C<make_collection_method($collection_type, $method_template)>

This class method makes a type safe method to wrap the collection api.
For instance, if called as:

  __PACKAGE__->make_collection_method('peer', 'add_X');

it creates a method that can be called as:

  $obj->add_peer($peer_id, { attr1 => $val1, attr2 => $val2 });

which is 'mapped' to a call to:

  $obj->add_item('peer', $peer_id, { attr1 => $val1, attr2 => $val2 });

=cut

sub make_collection_method {
  my $pkg = shift;
  my $collection_type = shift or $pkg->argh('BUG: missing collection type');
  my $method_template = shift or $pkg->argh('BUG: missing method template');
  my $new = $method_template;
  $new =~ s/X/$collection_type/;
  $new = __PACKAGE__.q{::}.$new;
  return if (defined &{"$new"});
  my $parent = $method_template;
  $parent =~ s/X/item/;
  #print STDERR "  $new => $parent\n";
  no strict 'refs';
  *{"$new"} =
    sub {
      my $self = shift;
      $self->$parent($collection_type, @_);
    };
  use strict 'refs';
  return 1;
}

=head2 C<make_item_attribute_method($collection_type, $attribute_name)>

This class method makes a type safe method to wrap the collection api.
For instance, called as:

  __PACKAGE__->make_item_attribute_method('peer', 'name');

it creates a method that can be called as:

  $obj->peer_name($peer_id);

or as:

  $obj->peer_name($peer_id, $name);

=cut

sub make_item_attribute_method {
  my $pkg = shift;
  my $collection_type = shift or $pkg->argh('BUG: missing collection type');
  my $attribute_name = shift or $pkg->argh('BUG: missing attribute name');
  my $new = __PACKAGE__.q{::}.$collection_type.q{_}.$attribute_name;
  return if (defined &{"$new"});
  #print STDERR "  $new => item_attrib\n";
  no strict 'refs';
  *{"$new"} =
    sub {
      my $self = shift;
      my $item = shift;
      $self->item_attrib($collection_type, $item, $attribute_name, @_);
    };
  use strict 'refs';
  return 1;
}

=head2 C<make_readonly_accessor($attrib)>

This class method makes a type safe method to access object attributes.
For instance, called as:

  __PACKAGE__->make_item_attribute_method('listen_port');

it creates a method that can be called as:

  $obj->listen_port();

=cut

sub make_readonly_accessor {
  my $pkg = shift;
  unless (@_) { $pkg->argh('BUG: missing attribute name'); }
  foreach my $attribute_name (@_) {
    my $new = __PACKAGE__.q{::}.$attribute_name;
    return if (defined &{"$new"});
    #print STDERR "  $new => readonly_accessor\n";
    no strict 'refs';
    *{"$new"} =
      sub {
        my $self = shift;
        $self->ouch_named($attribute_name,
                          'called with an argument, but '.
                            $attribute_name.' is readonly')
          if (@_);
        return $self->{'_'.$attribute_name};
      };
    use strict 'refs';
  }
  return 1;
}

=head1 HELPERS

=head2 C<module_available( $module, [ @import_arguments ])>

This method returns true if the named module is available.
Any optional additional arguments are passed to import
when loading the module.

=cut

sub module_available {
  my $self = shift;
  my $module = shift;
  return $self->{_mod}->{$module} if (exists $self->{_mod}->{$module});
  my $file = $module;
  $file =~ s!::!/!g;
  $file .= '.pm';
  return $self->{_mod}->{$module} = 1 if (exists $INC{$file});
  eval "require $module; import $module \@_;";
  return $self->{_mod}->{$module} = $EVAL_ERROR ? 0 : 1;
}

=head2 C<verbose( [ $new_verbose_setting ] )>

The method sets the verbose setting on the object.  Setting it to zero
should mean little or no output.  Setting it to 1 or more should
result in more messages.

=cut

sub verbose {
  my $self = shift;
  if (@_) {
    $self->{_verbose} = $_[0];
  }
  return $self->{_verbose};
}

=head2 C<argh(@message)>

This methods is just a helper to 'die' a helpful error messages.

=cut

sub argh {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my ($file, $line, $method) = (caller 1)[1,2,3];
  $method =~ s/.*:://;
  die $pkg."->$method: @_\n  at $file line $line.\n";
}

=head2 C<ouch(@message)>

This methods is just a helper to 'warn' a helpful error messages.

=cut

sub ouch {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my ($file, $line, $method) = (caller 1)[1,2,3];
  $method =~ s/.*:://;
  warn $pkg."->$method: @_\n  at $file line $line.\n";
  return;
}

=head2 C<argh_named(@message)>

This methods is just another helper to 'die' a helpful error messages.

=cut

sub argh_named {
  my $pkg = shift;
  my $name = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my ($file, $line) = (caller 1)[1,2];
  die $pkg."->$name: @_\n  at $file line $line.\n";
}

=head2 C<ouch_named(@message)>

This methods is just another helper to 'warn' a helpful error messages.

=cut

sub ouch_named {
  my $pkg = shift;
  my $name = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my ($file, $line) = (caller 1)[1,2];
  warn $pkg."->$name: @_\n  at $file line $line.\n";
  return;
}

1;
__END__

=head1 EXPORT

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
