package xPL::Config;

=head1 NAME

xPL::Config - Perl extension for xPL Config base class

=head1 SYNOPSIS

  use xPL::Config;

  my $config = xPL::Config->new($key) or die ";

=head1 DESCRIPTION

This module creates an xPL config which is used for clients supporting
C<config.*> xPL messages.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use Carp;
use DB_File;
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

sub new {
  my $pkg = shift;
  my %p = @_;
  my $key = $p{key};
  my $self = {};
  bless $self, $pkg;
  $self->{_config_spec} = read_spec($key) or return;
  $self->{_config} = load_config($key);

  return $self;
}

sub read_spec {
  my $key = shift;
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
    croak("Config spec in, $found, must contain a hash ref with\n",
          "items array ref\n");
  }
  my $cf = {};
  foreach my $item (@{$spec->{items}}) {
    my $name = $item->{name};
    $cf->{items}->{$name} = $item;
    push @{$cf->{order}}, $name;
  }
  return $cf;
}

sub load_config {
  my $key = shift;
  my $config_path = $ENV{XPL_CONFIG_PATH} || '/var/cache/xplperl';
  my $file = $config_path.'/'.$key.'.db';
  my %h;
  my $res = tie %h, 'DB_File', $file, O_CREAT|O_RDWR, 0666, $DB_HASH;
  unless ($res) {
    croak("Failed to create configuration DB_File, $file: $!\n");
  }
  return \%h;
}

sub items {
  return @{$_[0]->{_config_spec}->{order}};
}

sub number_of_items {
  return scalar @{$_[0]->{_config_spec}->{order}};
}

sub is_item {
  exists $_[0]->{_config_spec}->{items}->{$_[1]}
}

sub is_item_required {
  $_[0]->item_type($_[1]) =~ /^(?:reconf|config)$/;
}

sub max_item_values {
  $_[0]->{_config_spec}->{items}->{$_[1]}->{number} || 1;
}

sub item_type {
  $_[0]->{_config_spec}->{items}->{$_[1]}->{type} || 'option';
}

sub get_item {
  my $v = $_[0]->{_config}->{$_[1]};
  $_[0]->max_item_values($_[1]) > 1 ?
    [ split /\0/, $v ] : $v;
}

sub set_item {
  $_[0]->{_config}->{$_[1]} =
    $_[0]->max_item_values($_[1]) > 1 ? join chr(0), @{$_[2]} : $_[2];
}

sub update_item {
  my ($self, $name, $value) = @_;
  return unless ($self->is_item($name));
  my $old = $self->get_item($name);
  if (defined $old) {
    if ($self->max_item_values($name) > 1) {
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

sub config_types {
  my $self = shift;
  my %type = ();
  my $found;
  foreach my $name ($self->items) {
    $found++ if ($name eq 'newconf');
    my $num = $self->max_item_values($name);
    my $txt = $name;
    $txt .= '['.$num.']' if ($num > 1);
    push @{$type{$self->item_type($name)}}, $txt;
  }
  # always allow for instance_id configuration ('newconf' for some reason)
  unshift @{$type{'reconf'}}, 'newconf' unless ($found);

  my %body = ();
  foreach (qw/config reconf option/) {
    $body{$_} = $type{$_} if (exists $type{$_});
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

Copyright (C) 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
