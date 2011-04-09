package xPL::Config;

=head1 NAME

xPL::Config - Perl extension for xPL Config base class

=head1 SYNOPSIS

  use xPL::Config;

  my $config = xPL::Config->new($key) or die;

=head1 DESCRIPTION

This module creates an xPL config which is used for clients supporting
C<config.*> xPL messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Fcntl;
use Carp;
eval { require YAML::Syck; import YAML::Syck qw/LoadFile/; };
if ($@) {
  eval { require YAML; import YAML qw/LoadFile/; };
  croak("Failed to load YAML::Syck or YAML module: $@\n") if ($@);
}

use xPL::Base;

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

=head2 C<new(%params)>

The constructor creates a new xPL::Client object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item key

  The unique identifier for the configuration specification.
  Typically this is the 'vendor_id.device_id' from the xPL client.

=item instance

  The unique identifier for this instance of the configuration.
  Typically this is the 'instance_id' from the xPL client.

=back

It returns a blessed reference if a configuration specification is
found for the given key or undef otherwise.

=cut

sub new {
  my $pkg = shift;
  my %p = @_;
  my $self = {};
  bless $self, $pkg;
  my $key = $self->{_key} = $p{key};
  my $instance = $self->{_instance} = $p{instance};
  $self->_read_spec($key) or return;
  $self->_load_config($key.'.'.$instance);
  return $self;
}

=head2 C<items()>

This method returns a list of the names of the configuration items
in the order in which they are define.

=cut

sub items {
  return @{$_[0]->{_config_spec}->{order}};
}

=head2 C<number_of_items()>

This method returns the number of configuration items.

=cut

sub number_of_items {
  return scalar $_[0]->items
}

=head2 C<is_item($name)>

This method returns true if the given name is a valid item name.

=cut

sub is_item {
  exists $_[0]->{_config_spec}->{items}->{$_[1]}
}

=head2 C<is_item_required($name)>

This method returns true if the named item requires a value.  It
returns false if the item is optional.

=cut

sub is_item_required {
  $_[0]->item_type($_[1]) =~ /^(?:reconf|config)$/;
}

=head2 C<max_item_values($name)>

This method returns the number of values the named item can have.  It
returns 1 if the item is not multi-valued.

=cut

sub max_item_values {
  $_[0]->{_config_spec}->{items}->{$_[1]}->{number} || 1;
}

=head2 C<item_type($name)>

This method returns the type of the named item.

=cut

sub item_type {
  $_[0]->{_config_spec}->{items}->{$_[1]}->{type} || 'option';
}

=head2 C<get_item($name)>

This method returns the value of the named item.  For multi-valued
items it will always be an array reference.

=cut

sub get_item {
  my $v = $_[0]->{_config}->{$_[1]};
  $_[0]->max_item_values($_[1]) > 1 ?
    (defined $v ? [ split /\0/, $v ] : undef) : $v;
}

=head2 C<set_item($name, $value)>

This method sets the value of the named item.  For multi-valued items
it should be an array reference.

=cut

sub set_item {
  $_[0]->{_config}->{$_[1]} =
    $_[0]->max_item_values($_[1]) > 1 ?
      join chr(0), @{ref $_[2] ? $_[2] : [$_[2]]} :
        $_[2];
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
  return unless ($self->is_item($name));
  my $old = $self->get_item($name);
  if (defined $old) {
    if ($self->max_item_values($name) > 1) {
      $value = [$value] unless (ref $value);
      if (scalar @$old != scalar @$value) {
        $self->set_item($name, $value);
        return 'changed';
      } else {
        my $match = 1;
        for (my $i = 0; $i < scalar @$old; $i++) {
          if ($old->[$i] ne $value->[$i]) {
            $match = 0;
            last;
          }
        }
        unless ($match) {
          $self->set_item($name, $value);
          return 'changed';
        }
      }
    } elsif ($old ne $value) {
      $self->set_item($name, $value);
      return 'changed';
    }
  } else {
    $self->set_item($name, $value);
    return 'set';
  }
  return;
}

=head2 C<items_requiring_config()>

This method returns a list of the items that are mandatory and which
are currently unconfigured.

=cut

sub items_requiring_config {
  my $self = shift;
  my @needed;
  foreach my $name ($self->items) {
    push @needed, $name
      if ($self->is_item_required($name) &&
          !defined $self->get_item($name));
  }
  return @needed;
}

=head2 C<config_types()>

This method returns a hash reference contain keys for each element
where the values are the types of the items suffixed with '[NN]' for
multi-valued items where 'NN' is the maximum number of values.

=cut

sub config_types {
  my $self = shift;
  my %type = ();
  foreach my $name ($self->items) {
    my $num = $self->max_item_values($name);
    my $txt = $name;
    $txt .= '['.$num.']' if ($num > 1);
    push @{$type{$self->item_type($name)}}, $txt;
  }

  my %body = ();
  foreach (qw/config reconf option/) {
    $body{$_} = $type{$_} if (exists $type{$_});
  }
  return \%body;
}

=head2 C<config_current()>

This method returns a hash reference contain keys for each element
where the values are values of the items.

=cut

sub config_current {
  my $self = shift;
  my %body = ();
  foreach my $name ($self->items) {
    my $val = $self->get_item($name);
    $body{$name} = defined $val ? $val : '';
  }
  return \%body;
}

=head1 INTERNAL METHODS

=head2 C<_read_spec($key)>

This method reads the specification for the given key.  It looks for
the file, C<<'xPL/config/<key>.yaml'>> on the C<@INC> include path.  The
C<YAML> configuration should be a hash reference with an entry for the
key C<items> with an array reference of configurable items.  Each
configurable item is a hash reference containing the following keys:

=over 4

=item name

  This is the name of the configuration item.  This is a mandatory
  element.

=item type

  The type of the configuration item.  This must be one of:

=over 4

=item config

  This type is for items that are mandatory for the device to function
  and that cannot be changed once a device is running.

=item reconf

  This type is for items which are mandatory for the device to
  operate, but who's value can be changed at any time while the device
  is operating.

=item option

  This type is for items that are not required for device operation -
  typically items for which the client has a suitable default.

=back

  This key is optional and defaults to 'option'.

=item number

  The number of values this element may have.  This key is optional and
  defaults to '1'.

=back

This method returns true if a valid configuration specification is
found.  It croaks if an invalid configuration specifications is found.
It returns undef if no configuration specification is found.

=cut

sub _read_spec {
  my ($self, $key) = @_;
  my $file = 'xPL/config/'.$key.'.yaml';
  my $found;
  foreach (@INC) {
    my $path = $_.'/'.$file;
    if (-f $path) {
      $found = $path;
      last;
    }
  }
  return unless ($found);
  my $spec;
  eval { $spec = LoadFile($found); };
  if ($@) {
    croak("Failed to read config spec from $found\n", $@, "\n");
  }
  unless (ref $spec && ref $spec eq 'HASH' &&
          ref $spec->{items} && ref $spec->{items} eq 'ARRAY') {
    croak("Config spec in, $found,\n",
          "must contain a hash ref with items array ref\n");
  }
  my $cf = $self->{_config_spec} = {};
  my $newconf;
  foreach my $item (@{$spec->{items}}) {
    my $name = $item->{name};
    $newconf++ if ($name eq 'newconf');
    $cf->{items}->{$name} = $item;
    push @{$cf->{order}}, $name;
  }
  # always allow for instance_id configuration ('newconf' for some reason)
  unless ($newconf) {
    unshift @{$cf->{order}}, 'newconf';
    $cf->{items}->{'newconf'} = { name => 'newconf' };
  }

  return 1;
}

=head2 C<_load_config($instance_key)>

This method loads the configuration for a specific instance.  It returns
true if successful or croaks otherwise.

=cut

sub _load_config {
  my ($self, $instance_key) = @_;
  my $config_path = $ENV{XPL_CONFIG_PATH} || '/var/cache/xpl-perl';
  my $file = $config_path.'/'.$instance_key.'.db';
  my %h;
  eval { require DB_File; import DB_File; };
  croak("DB_File module required to use xPL config.basic support.\n") if ($@);
  my $res = tie %h, 'DB_File', $file, O_CREAT|O_RDWR, 0666, $DB_File::DB_HASH;
  unless ($res) {
    croak("Failed to create configuration DB_File, $file: $!\n");
  }
  $self->{_config} = \%h;
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
