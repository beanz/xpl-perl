package xPL::Message;

# $Id$

=head1 NAME

xPL::Message - Perl extension for xPL message base class

=head1 SYNOPSIS

  use xPL::Message;

  my $msg = xPL::Message->new(message_type => 'xpl-stat',
                              head =>
                              {
                               hop => 1,
                               source => 'acme-lamp.livingroom',
                               target => '*',
                              },
                              class => 'hbeat.app',
                              body =>
                              {
                               interval => 10,
                               port => 12345,
                               remote_ip => '127.0.0.1',
                               extra => 'value in my extra field',
                              },
                             );

  # let's leave out some fields and let them use the defaults
  $msg = xPL::Message->new(head =>
                           {
                            source => 'acme-lamp.livingroom',
                           },
                           class => 'hbeat.app',
                           body =>
                           {
                            remote_ip => '127.0.0.1',
                            extra => 'value in my extra field',
                           },
                          );

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use English qw/-no_match_vars/;
use xPL::Validation;

use xPL::Base;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our %modules = ();

our $LF = "\012";
our $EMPTY = q{};
our $DOT = q{.};
our $STAR = q{*};
our $EQUALS = q{=};
our $DOUBLE_COLON = q{::};

__PACKAGE__->make_readonly_accessor(qw/class class_type/);

=head2 C<new(%parameter_hash)>

The constructor creates a new xPL::Message object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item message_type

  The message type identifier.  Valid values are 'xpl-cmnd',
  'xpl-stat' and 'xpl-trig', for each of the three styles of xPL
  Message.

=item class

  The class or schema of the message.  This can either by just the
  first part of the class, such as 'hbeat', (in which case the
  'class_type' parameter must also be present) or it can be the
  full schema name, such as 'hbeat.basic'.  This field is used
  to determine the type of xPL Message object that will actually
  be instantiated and returned to the caller.

=item class_type

  The type of the schema.  For the schema, 'hbeat.basic' the class
  type is 'basic'.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my %p = @_;
  exists $p{head} or  $p{head} = {};
  exists $p{body} or $p{body} = {};
  exists $p{strict} or $p{strict} = 1;

  my $class;
  my $class_type;
  defined $p{class} or $pkg->argh(q{requires 'class' parameter});
  if ($p{class} =~ /^([A-Z0-9]{1,8})\.([A-Z0-9]{1,8})$/i) {
    $class = $1;
    $class_type = $2;
  } elsif (!defined $p{class_type}) {
    $pkg->argh(q{requires 'class_type' parameter});
  } elsif ($p{class} =~ /^[A-Z0-9]{1,8}$/i) {
    if ($p{class_type} =~ /^[A-Z0-9]{1,8}$/i) {
      $class = $p{class};
      $class_type = $p{class_type};
    } else {
      $pkg->argh("'class_type' parameter is invalid.\n".
                  'It must be 8 characters from A-Z, a-z and 0-9.');
    }
  } else {
    $pkg->argh("'class' parameter is invalid.\n".
                'It must be 8 characters from A-Z, a-z and 0-9.');
  }
  delete $p{class};
  delete $p{class_type};

  my $module = $pkg.$DOUBLE_COLON.(lc $class).$DOUBLE_COLON.(lc $class_type);
  unless (exists $modules{$module}) {

    # At some point this will probably be change to generate the subclass
    # on-the-fly from some form of machine readable schema definition.

    eval "require $module; import $module;";
    if ($EVAL_ERROR) {
      $modules{$module} = $pkg; # default for unknown class type
      if (exists $ENV{XPL_MSG_WARN}) {
        warn "Failed to load $module: ".$EVAL_ERROR;
      }
    } else {
      $modules{$module} = $module;
      $module->make_body_fields();
    }
  }
  $module = $modules{$module};

  my $self = {};
  bless $self, $module;

  $self->verbose($p{verbose}||0);

  $self->{_class} = $class;
  $self->{_class_type} = $class_type;

  if (!exists $p{message_type} && $self->default_message_type()) {
    $p{message_type} = $self->default_message_type();
  }

  $self->strict($p{strict});

  # process message_type
  exists $p{message_type} or
    $self->argh("requires 'message_type' parameter");
  $self->message_type($p{message_type});
  delete $p{message_type};

  $self->parse_head_parameters($p{head});
  $self->parse_body_parameters($p{body});

  $self->{_extra_order} = [];
  foreach ($p{body_order} ? @{$p{body_order}} : keys %{$p{body}}) {
    next unless (exists $p{body}->{$_});
    $self->extra_field($_, $p{body}->{$_});
  }
  $self->{_head_order} = $p{head_order} || [qw/hop source target/];

  return $self;
}

=head2 C<new_from_payload( $message )>

This is a constructor that takes the string of an xPL message and
constructs an xPL::Message object from it.

=cut

sub new_from_payload {
  my $pkg = shift;
  my $msg = shift;
  my %r = ();
  my ($head, $body, $null) = split /\n}\n/, $msg, 3;
  unless (defined $head) {
    xPL::Message->argh('Message badly formed: empty?');
  }
  unless (defined $body) {
    xPL::Message->argh('Message badly formed: failed to split head and body');
  }
  unless (defined $null) {
    xPL::Message->ouch('Message badly terminated: missing final eol char?');
    $body =~ s/\n}$//;
  }
  if ($null) {
    xPL::Message->ouch("Trailing trash: $null\n");
  }
  unless ($head =~ /^(.*?)\n\{\n(.*)$/s) {
    xPL::Message->argh("Invalid header: $head\n");
  }
  $r{message_type} = $1;
  foreach (split /\n/, $2) {
    my ($k, $v) = split /=/, $_, 2;
    $k =~ s/-/_/g;
    $r{head}->{$k} = $v;
    push @{$r{head_order}}, $k;
  }

  unless ($body =~ /^(.*?)\n\{\n(.*)$/s) {
    xPL::Message->argh("Invalid body: $body\n");
  }
  my $b_content = $2;
  @r{qw/class class_type/} = split /\./, $1, 2;
  foreach (split /\n/, $2) {
    my ($k, $v) = split /=/, $_, 2;
    $k =~ s/-/_/g;
    if (exists $r{body}->{$k}) {
      xPL::Message->ouch('Repeated body field: '.$k);
      next;
    }
    $r{body}->{$k} = $v;
    push @{$r{body_order}}, $k;
 }
  return $pkg->new(strict => 0, %r);
}

=head2 C<field_spec()>

This is the default field specification.  It is empty.  Specific
message classes are intended to override this method.

=cut

sub field_spec {
  []
}

=head2 C<parse_head_parameters( $head_hash_ref )>

This method is called by the constructor to process the fields of the
header of the message.

=cut

sub parse_head_parameters {
  my $self = shift;
  my $head = shift;
    # process fields from the header
  foreach ([ hop => 1 ],
           [ source => undef ],
           [ target => "*" ],
          ) {
    my ($param, $default) = @$_;
    unless (exists $head->{$param}) {
      if (defined $default) {
        $head->{$param} = $default;
      } else {
        $self->argh("requires '$param' parameter");
      }
    }
    $self->$param($head->{$param});
    delete $head->{$param};
  }
  return 1;
}

=head2 C<parse_body_parameters( $body_hash_ref )>

This method is called by the constructor to process the fields of the
body of the message according to the field specification for the
message type.

=cut

sub parse_body_parameters {
  my $self = shift;
  my $body = shift;
  my $spec = $self->field_spec();
  foreach my $field_rec (@$spec) {
    $self->process_field_record($body, $field_rec);
  }
  return 1;
}

=head2 C<process_field_record( $body_hash_ref, $field_record_hash_ref )>

This method is called by the constructor to process a single field
in body of the message according to the field specification for the
message type.

=cut

sub process_field_record {
  my $self = shift;
  my $body = shift;
  my $rec = shift;
  my $name = $rec->{name};
  unless (exists $body->{$name}) {
    if (exists $rec->{default}) {
      $body->{$name} = $rec->{default};
    } elsif (exists $rec->{required}) {
      $self->argh("requires '$name' parameter in body");
    } else {
      return 1;
    }
  }
  $self->$name($body->{$name});
  delete $body->{$name};
  return 1;
}

=head2 C<default_message_type()>

This method returns the default message type.  It is undefined for
the base class, but it can be overriden.

=cut

sub default_message_type {
  return;
}

=head2 C<summary()>

This method returns a string containing a summary of the xPL message.
It is intended for use when logging.  This method is intended to be
overriden so that specific messages can append brief relevant data
to the common components of the summary.

=cut

sub summary {
  my $self = shift;
  return
    sprintf
      '%s/%s.%s: %s -> %s',
      $self->message_type,
      $self->class, $self->class_type,
      $self->source, $self->target;
}

=head2 C<string()>

This method returns the xPL message string.  It is made up of the
L<head_string()> and L<body_string()>.

=cut

sub string {
  my $self = shift;
  return $self->head_string(@_).$self->body_string(@_);
}

=head2 C<head_string()>

This method returns the string that makes up the head part of the xPL
message.

=cut

sub head_string {
  my $self = shift;
  my $h = $self->message_type."$LF\{$LF";
  foreach (@{$self->{_head_order}}) {
    $h .= $_.$EQUALS.$self->$_().$LF;
  }
  $h .= "}$LF";
  return $h;
}

=head2 C<body_string()>

This method returns the string that makes up the body part of the xPL
message.

=cut

sub body_string {
  my $self = shift;
  my $b = $self->class.$DOT.$self->class_type."$LF\{$LF";
  foreach ($self->body_fields()) {
    my $v = $self->$_();
    my $n = $_;
    $n =~ s/_/-/g;
    $b .= "$n=".$v."$LF" if (defined $v);
  }
  $b .= $self->extra_field_string();
  $b .= "}$LF";
  return $b;
}

=head2 C<strict( [ $new_strictness ] )>

This method returns the strictness setting for this message.  If the
optional new value argument is present, then this method updates the
message type identifier with the new value before it returns.

Strictness defines whether or not the message is validated harshly or
not.  Typically outgoing messages would have strictness turned on and
incoming messages would not.

=cut

sub strict {
  my $self = shift;
  if (@_) {
    $self->{_strict} = $_[0];
  }
  return $self->{_strict};
}

=head2 C<message_type( [ $new_message_type ] )>

This method returns the message type identifier.  If the optional new
value argument is present, then this method updates the message type
identifier with the new value before it returns.

=cut

sub message_type {
  my $self = shift;
  if (@_) {
    my $value = $_[0];
    unless (!$self->strict ||
            $value =~ /^XPL-CMND|XPL-STAT|XPL-TRIG$/i) {
      $self->argh("message type identifier, $value, is invalid.\n".
                  'It should be one of XPL-CMND, XPL-STAT or XPL-TRIG.');
    }
    $self->{_message_type} = $value;
  }
  return $self->{_message_type};
}

=head2 C<hop( [ $new_hop ] )>

This method returns the hop count.  If the optional new value argument
is present, then this method updates the hop count to the new value
before it returns.

=cut

sub hop {
  my $self = shift;
  if (@_) {
    my $value = $_[0];
    unless (!$self->strict || $value =~ /^[1-9]$/) {
      $self->argh("hop count, $value, is invalid.\n".
                  'It should be a value from 1 to 9');
    }
    $self->{_hop} = $value;
  }
  return $self->{_hop};
}

=head2 C<source( [ $new_source ] )>

This method returns the source id.  If the optional new value argument
is present, then this method updates the source id to the new value
before it returns.

=cut

sub source {
  my $self = shift;
  if (@_) {
    my $value = $_[0];
    my $valid = valid_id($value);
    unless (!$self->strict || $valid eq 'valid') {
      $self->argh("source, $value, is invalid.\n$valid");
    }
    $self->{_source} = $value;
  }
  return $self->{_source};
}

=head2 C<target( [ $new_target ] )>

This method returns the target id.  If the optional new value argument
is present, then this method updates the target id to the new value
before it returns.

=cut

sub target {
  my $self = shift;
  if (@_) {
    my $value = $_[0];
    if ($value ne $STAR) {
      my $valid = valid_id($value);
      unless (!$self->strict || $valid eq 'valid') {
        $self->argh("target, $value, is invalid.\n$valid");
      }
    }
    $self->{_target} = $value;
  }
  return $self->{_target};
}

=head2 C<class()>

This method returns the class.

=head2 C<class_type()>

This method returns the class type.

=head2 C<valid_id( $identifier )>

This is a helper function (not a method) that return the string
'valid' if the given identifier is valid.  Otherwise it returns a
string with details of why the identifier is invalid.

=cut

sub valid_id {
  unless ($_[0] =~ m!^(.*)-(.*)\.(.*)$!) {
    return q{Invalid format - should be 'vendor-device.instance'.};
  }
  my ($vendor, $device, $instance) = ($1, $2, $3);
  unless ($vendor =~ /^[A-Z0-9]{1,8}$/i) {
    return 'Invalid vendor id - maximum of 8 chars from A-Z, a-z, and 0-9.';
  }
  unless ($device =~ /^[A-Z0-9]{1,8}$/i) {
    return 'Invalid device id - maximum of 8 chars from A-Z, a-z, and 0-9.';
  }
  unless ($instance =~ /^[A-Z0-9]{1,16}$/i) {
    return 'Invalid instance id - maximum of 16 chars from A-Z, a-z, and 0-9.';
  }
  return 'valid';
}

=head2 C<extra_field( $field, [ $value ] )>

This method returns the value of the extra field from the message
body.  If the optional new value argument is present, then this method
updates the extra field with the new value before it returns.

=cut

sub extra_field {
  my $self = shift;
  my $key = shift;
  if (@_) {
    push @{$self->{_extra_order}}, $key;
    $self->{_extra}->{$key} = $_[0];
  }
  return $self->{_extra}->{$key};
}

=head2 C<extra_fields()>

This method returns the names of the extra fields present in this
message.

=cut

sub extra_fields {
  my $self = shift;
  return @{$self->{_extra_order}};
}

=head2 C<extra_field_string()>

This method returns a formatted string that forms the part of the xPL
message body that contains the extra fields.

=cut

sub extra_field_string {
  my $self = shift;
  my $b = $EMPTY;
  foreach ($self->extra_fields) {
    $b .= $_.$EQUALS.$self->extra_field($_).$LF;
  }
  return $b;
}

=head2 C<body_fields()>

This method returns the fields that are in the body of this message.

=cut

sub body_fields {
  return;
}

=head2 C<make_body_fields( )>

This method populates the symbol table.  It creates the methods for
the fields listed in the L<field_spec> for the message sub-classes.
It also creates a C<body_fields> method from the specification.

=cut

sub make_body_fields {
  my $pkg = shift;
  my @f = ();
  foreach my $rec (@{$pkg->field_spec()}) {
    $pkg->make_body_field($rec);
    push @f, $rec->{name};
  }
  my $new = $pkg.'::body_fields';
  return if (defined &{$new});
#  print STDERR "  $new => make_body_fields, @f\n";
  no strict qw/refs/;
  *{$new} =
    sub {
      my $self = shift;
      return @f;
    };
  use strict qw/refs/;
  return 1;
}

=head2 C<make_body_field( $record )>

This class method makes a type safe method to get/set the named field
of the xPL Message body.

For instance, called as:

  __PACKAGE__->make_body_field({
                                name => 'interval',
                                xPL::Validation->new(type => 'integer',
                                                     min => 5, max => 30 ),
                                error => 'It should be blah, blah, blah.',
                               );

it creates a method that can be called as:

  $msg->interval(5);

or:

  my $interval = $msg->interval();

=cut

sub make_body_field {
  my $pkg = shift;
  my $rec = shift or $pkg->argh('BUG: missing body field record');
  my $name = $rec->{name} or
    $pkg->argh('BUG: missing body field record missing name');
  my $validation = $rec->{validation} or
    $pkg->argh('BUG: missing body field record missing validation');
  my $die = $rec->{die} || 0;
  my $error_message =
    exists $rec->{error} ? $rec->{error} : $validation->error();

  my $error_handler = $die ? "argh_named" : "ouch_named";
  my $new = $pkg.q{::}.$name;
  return if (defined &{$new});
#  print STDERR "  $new => body_field, ",$validation->summary,"\n";
  no strict qw/refs/;
  *{$new} =
    sub {
      my $self = shift;
      if (@_) {
        my $value = shift;
        if ($self->strict && !$validation->valid($value)) {
          $self->$error_handler($name,
                                $name.", ".$value.", is invalid.\n".
                                $error_message);
        }
        $self->{_body}->{$name} = $value;
      }
      return $self->{_body}->{$name};
    };
  use strict qw/refs/;
  return 1;
}

1;
__END__

=head1 TODO

There are some 'todo' items for this module:

=over 4

=item Support for additional developer fields in the header of xPL messages.

=back

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
