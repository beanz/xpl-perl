package xPL::Base;

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
use Carp;
use English qw/-no_match_vars/;
use Socket;
use Text::Balanced qw/extract_quotelike/;
use Time::HiRes;

use Exporter;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw(simple_tokenizer) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.12';
our $SVNVERSION = qw/$Revision$/[1];

my $EMPTY = q{};
my $SLASH = q{/};
my $DOT = q{.};

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
  if (exists $self->{_col}->{$type}->{$id}) {
    $self->argh("$type item '$id' already registered");
  }
  $attribs->{'!type!'} = $type;
  $attribs->{'!id!'} = $id;
  $attribs->{'!debug!'} = $type.'|'.$id;
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
  unless (exists $self->{_col}->{$type}->{$id}) {
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
  unless (exists $self->{_col}->{$type}->{$id}) {
    return $self->ouch("$type item '$id' not registered");
  }
  my $key = shift or $self->argh('missing key');
  if (@_) {
    $self->{_col}->{$type}->{$id}->{$key} = $_[0];
  }
  return $self->{_col}->{$type}->{$id}->{$key};
}

sub _item_attrib {
  my $self = shift;
  my $type = shift;
  my $id = shift or $self->argh_named('item_attrib', 'BUG: item id missing');
  unless (exists $self->{_col}->{$type}->{$id}) {
    return $self->ouch_named('item_attrib', "$type item '$id' not registered");
  }
  my $key = shift or $self->argh_named('item_attrib', 'missing key');
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
  $attribs->{callback_time_total} = 0;
  $attribs->{callback_time_max} = 0;
  return $attribs;
}

=head2 C<call_callback($type, $name)>

This method wraps calls to callbacks in order to collect statistics.

=cut

sub call_callback {
  my $self = shift;
  my $type = shift;
  my $name = shift;
  exists $self->{_col}->{$type}->{$name} or
    return $self->argh("BUG: callback $name of type, $type, doesn't exist");
  my $r = $self->{_col}->{$type}->{$name};
  my $t = Time::HiRes::time;
  my $res = &{$r->{callback}}(@_, arguments => $r->{arguments}, xpl => $self,
                              id => $name);
  $t = Time::HiRes::time - $t;
  $r->{callback_time_total} += $t;
  if ($r->{callback_time_max} < $t) {
    $r->{callback_time_max} = $t;
#    print STDERR "New callback maximum: ", $r->{'!debug!'}, " = ", $t, "\n";
  }
  $r->{callback_count}++;
  return $res;
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
  $new = $pkg.q{::}.$new;
  return if (defined &{"$new"});
  my $parent = $method_template;
  $parent =~ s/X/item/;
  #print STDERR "  $new => $parent\n";
  no strict 'refs'; ## no critic
  *{"$new"} =
    sub {
      shift->$parent($collection_type, @_);
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
  my $new = $pkg.q{::}.$collection_type.q{_}.$attribute_name;
  return if (defined &{"$new"});
  #print STDERR "  $new => item_attrib\n";
  no strict 'refs'; ## no critic
  *{"$new"} =
    sub {
      shift->_item_attrib($collection_type, shift, $attribute_name, @_);
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
    my $new = $pkg.q{::}.$attribute_name;
    return if (defined &{"$new"});
    #print STDERR "  $new => readonly_accessor\n";
    no strict 'refs'; ## no critic
    *{"$new"} =
      sub {
        $_[0]->ouch_named($attribute_name,
                          'called with an argument, but '.
                            $attribute_name.' is readonly')
          if (@_ > 1);
        $_[0]->{'_'.$attribute_name};
      };
    use strict 'refs';
  }
  return 1;
}

=head1 HELPERS

=head2 C<default_interface_info()>

This method returns a hash reference containing keys for 'device',
'address', 'broadcast', and 'netmask' for the interface that the
simple heuristic thinks would be a good default.  The heuristic
is currently first interface that isn't loopback.

=cut

sub default_interface_info {
  my $self = shift;
  my $res = $self->interfaces();
  foreach my $if (@$res) {
    next if ($if->{device} eq 'lo' or $if->{device} eq 'lo0');
    return $if;
  }
  return;
}

=head2 C<is_local_address( $ip )>

This method returns true if the given IP address is one of the
addresses of our interfaces.

=cut

sub is_local_address {
  my $self = shift;
  my $ip = shift;
  my $res = $self->interfaces();
  foreach my $if (@$res) {
    return 1 if ($if->{ip} eq $ip);
  }
  return;
}

=head2 C<interface_ip($if)>

This method returns the ip address associated with the named interface.

=cut

sub interface_ip {
  my $self = shift;
  my $res = $self->interface_info(@_);
  return $res ? $res->{ip} : undef;
}

=head2 C<interface_broadcast($if)>

This method returns the broadcast address associated with the named
interface.

=cut

sub interface_broadcast {
  my $self = shift;
  my $res = $self->interface_info(@_);
  return $res ? $res->{broadcast} : undef;
}

=head2 C<interface_info($if)>

This method returns a hash reference containing keys for 'device',
'address', 'broadcast', and 'netmask' for the named interface.

=cut

sub interface_info {
  my $self = shift;
  my $ifname = shift;
  my $res = $self->interfaces();
  foreach my $if (@$res) {
    return $if if ($if->{device} eq $ifname);
    # hack for portability on macosx
    return $if if ($ifname eq 'lo' && $if->{device} eq 'lo0');
  }
  return;
}

=head2 C<interfaces()>

This method returns a list reference of network interfaces.  Each
element of the list is a hash reference containing keys for
'device', 'address', 'broadcast', and 'netmask'.

=cut

sub interfaces {
  my $self = shift;
  # cache the results of interface lookups
  unless (exists $self->{_interfaces}) {
    # I was going to use Net::Ifconfig::Wrapper but it appears to hide
    # the order of interfaces.  This is important since I wanted to make
    # the first non-loopback interface the default
    my $interfaces = $self->interfaces_ifconfig();
    $interfaces = $self->interfaces_ip() unless($interfaces && @{$interfaces});
    $self->{_interfaces} = $interfaces || [];
  }
  return $self->{_interfaces};
}

=head2 C<interfaces_ip()>

This method returns a list reference of network interfaces.  Each
element of the list is a hash reference containing keys for
'device', 'address', 'broadcast', and 'netmask'.  It is implemented
using the modern C<ip> command.

=cut

sub interfaces_ip {
  my $self = shift;
  my $command = $self->find_in_path('ip') or return;
  my @res;
  open my $fh, '-|', $command, qw/addr show/;
  my $if;
  while (<$fh>) {
    if (/^\d+:\s+([a-zA-Z0-9:]+):/) {
      $if = $1;
    } elsif (/inet (\d+\.\d+\.\d+\.\d+)\/\d+\s+brd\s+(\d+\.\d+\.\d+\.\d+)/i) {
      push @res, { device => $if, ip => $1, broadcast => $2, src => 'ip' };
    } elsif ($if =~ /^lo/ && /inet (\d+\.\d+\.\d+\.\d+)\/(\d+)/) {
      push @res,
        {
         device => $if,
         ip => $1,
         broadcast => $1,
         src => 'ip',
        };
    }
  }
  close $fh;
  return \@res;
}

=head2 C<interfaces_ifconfig()>

This method returns a list reference of network interfaces.  Each
element of the list is a hash reference containing keys for
'device', 'address', 'broadcast', and 'netmask'.  It is implemented
using the traditional C<ifconfig> command.

=cut

sub interfaces_ifconfig {
  my $self = shift;
  my $command = $self->find_in_path('ifconfig') or return;
  my @res;
  open my $fh, '-|', $command, '-a';
  my $rec;
  while (<$fh>) {
    if (/^([a-zA-Z0-9:]+):\s+flags/ or /^([a-zA-Z0-9:]+)\s*Link/) {
      push @res, $rec if ($rec && $rec->{ip} && $rec->{broadcast});
      $rec = { device => $1, src => 'ifconfig', };
    }
    if ($rec && /mask:(\d+\.\d+\.\d+\.\d+)\s+/i) {
      $rec->{mask} = $1;
    }
    if ($rec && /netmask 0x([A-Fa-f0-9]{8})/) {
      $rec->{mask} = join ".", unpack "C*", pack "H*", $1;
    }
    if ($rec && /inet\s*(?:addr:)?(\d+\.\d+\.\d+\.\d+)\s+/) {
      $rec->{ip} = $1;
      if ($rec->{device} =~ /^lo0?$/) {
        # special case for loopback which isn't strictly broadcast
        $rec->{broadcast} = $rec->{ip};
      }
    }
    if ($rec && /(?:broadcast|bcast:)\s*(\d+\.\d+\.\d+\.\d+)\s+/i) {
      $rec->{broadcast} = $1;
    }
  }
  close $fh;
  push @res, $rec if ($rec && $rec->{ip} && $rec->{broadcast});
  return \@res;
}

=head2 C<broadcast_from_mask( $ip, $mask )>

This function returns the broadcast address based on a given ip address
and netmask.

=cut

sub broadcast_from_mask {
  my $ip = shift;
  my $mask = shift;
  my @ip = unpack 'C4', inet_aton($ip);
  my @m = unpack 'C4', inet_aton($mask);
  my @b;
  foreach (0..3) {
    push @b, $ip[$_] | 255-$m[$_];
  }
  return join $DOT, @b;
}

=head2 C<broadcast_from_class( $ip, $class )>

This function returns the broadcast address based on a given ip address
and an number of bits representing the address class.

=cut

sub broadcast_from_class {
  my $ip = shift;
  my $class = shift;
  my @m;
  foreach (0..3) {
    if ($class > 8) {
      $m[$_] = 255;
      $class-=8;
    } else {
      $m[$_] = 255-(2**(8-$class)-1);
      $class=0
    }
  }
  return broadcast_from_mask($ip, join $DOT, @m);
}

=head2 C<find_in_path( $command )>

This method is use to find commands in the PATH.  It is mostly
here to avoid the error messages that might appear if you try
to execute something that isn't in the PATH.

=cut

sub find_in_path {
  my $self = shift;
  my $command = shift;
  my @path = split /:/, $ENV{PATH};
  # be sure to check /sbin unless we are in the Test::Harness
  push @path, '/sbin' unless ($ENV{TEST_HARNESS_OVERRIDE});
  foreach my $path (@path) {
    my $f = $path.$SLASH.$command;
    if (-x $f) {
      return $f;
    }
  }
  return;
}

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
  eval "require $module";
  my $res;
  if ($EVAL_ERROR) {
    $self->{_mod}->{$module} = 0;
  } else {
    import $module @_;
    $self->{_mod}->{$module} = 1;
  }
  return $self->{_mod}->{$module}
}

=head2 C<simple_tokenizer( $string )>

This function takes a string of the form:

  "-a setting1 -b setting2 key1=val1 key2=val2"

and returns a list like:

  '-a', 'setting1', '-b', 'setting2', 'key1', 'val1', 'key2', 'val2'

It attempts to handle quoted values.  It is expected that the list
will be cast in to a hash.

=cut

sub simple_tokenizer {
  my $str = $_[0];
  my @r = ();
  my $w = '[-+\._a-zA-Z0-9]';
  my $s = '[= \t]';
  my $q = q{["']};
  while ($str) {
    my $t = extract_quotelike($str);
    if ($t) {
      $t =~ s/^$q//o;
      $t =~ s/$q$//o;
      $t =~ s/\\($q)/$1/go;
      if ($t =~ /^\[([^\]]*)\]$/) {
        $t = [ split /,/, $1 ];
      }
      push @r, $t;
      $str =~s/^$s+//o;
    } elsif ($str =~ s/^($w+)$s*//o) {
      push @r, $1;
    } else {
      push @r, $str;
      $str=$EMPTY;
    }
  }
  return @r;
}

=head2 C<verbose( [ $new_verbose_setting ] )>

The method sets the verbose setting on the object.  Setting it to zero
should mean little or no output.  Setting it to 1 or more should
result in more messages.

=cut

sub verbose {
  return $_[0]->{_verbose} unless (@_ > 1);
  $_[0]->{_verbose} = $_[1];
}

=head2 C<info(@message)>

Helper method to output informational messages to STDOUT if verbose
mode is enabled.

=cut

sub info {
  my $self = shift;
  print @_ if ($self->{_verbose});
}

=head2 C<debug(@message)>

Helper method to output debug messages to STDERR if verbose mode is
enabled.

=cut

sub debug {
  my $self = shift;
  print STDERR @_ if ($self->{_verbose});
}

=head2 C<argh(@message)>

This methods is just a helper to 'die' a helpful error messages.

=cut

sub argh {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my $method = (caller 1)[3];
  $method =~ s/.*:://;
  croak $pkg."->$method: @_\n";
}

=head2 C<ouch(@message)>

This methods is just a helper to 'warn' a helpful error messages.

=cut

sub ouch {
  my $pkg = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  my $method = (caller 1)[3];
  $method =~ s/.*:://;
  carp $pkg."->$method: @_\n";
  return;
}

=head2 C<argh_named($method_name, @message)>

This methods is just another helper to 'die' a helpful error messages.

=cut

sub argh_named {
  my $pkg = shift;
  my $name = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  croak $pkg."->$name: @_\n";
}

=head2 C<ouch_named($method_name, @message)>

This methods is just another helper to 'warn' a helpful error messages.

=cut

sub ouch_named {
  my $pkg = shift;
  my $name = shift;
  if (ref $pkg) { $pkg = ref $pkg }
  carp $pkg."->$name: @_\n";
  return;
}

1;
__END__

=head1 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
