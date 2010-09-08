package xPL::Message;

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
use Carp qw/confess/;

use xPL::Base;
#use AutoLoader qw(AUTOLOAD);

our @ISA = qw(xPL::Base);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

our $LF = "\012";
our $EMPTY = q{};
our $DOT = q{.};
our $SPACE= q{ };
our $STAR = q{*};
our $EQUALS = q{=};
our $DOUBLE_COLON = q{::};
our $SPACE_DASH_SPACE = q{ - };
our $COMMA = q{,};
our $OPEN_SQUARE_BRACKET = q{[};
our $CLOSE_SQUARE_BRACKET = q{]};
our %MESSAGE_TYPES = map { $_ => 1 } qw/xpl-cmnd xpl-stat xpl-trig/;

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

  # process message_type
  exists $p{message_type} or $pkg->argh(q{requires 'message_type' parameter});
  my $message_type = $p{message_type};
  delete $p{message_type};
  exists $MESSAGE_TYPES{$message_type} or
    $pkg->argh("message type identifier, $message_type, is invalid.\n".
               'It should be one of xpl-cmnd, xpl-stat or xpl-trig.');

  my $self = {};
  bless $self, $pkg;

  $self->{_verbose} = $p{verbose}||0;

  $self->{_class} = $class;
  $self->{_class_type} = $class_type;
  $self->{_message_type} = $message_type;

  if ($p{head_content}) {
    $self->{_head_content} = $p{head_content};
  } else {
    exists $p{head} or $p{head} = {};
    $self->parse_head_parameters($p{head}, $p{head_order});
  }

  if ($p{body_content}) {
    $self->{_body_content} = $p{body_content};
  } else {
    exists $p{body} or $p{body} = [];
    $self->parse_body_parameters($p{body}, $p{body_order});
  }
  return $self;
}

=head2 C<new_from_payload( $message )>

This is a constructor that takes the string of an xPL message and
constructs an xPL::Message object from it.

=cut

sub new_from_payload {
  my %r = ();
  my ($head, $body, $null) = split /\n}\n/, $_[1], 3;
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
  $r{head_content} = $2;

  unless ($body =~ /^(.*?)\n\{\n?(.*)$/s) {
    xPL::Message->argh("Invalid body: $body\n");
  }
  $r{body_content} = $2;
  @r{qw/class class_type/} = split /\./, $1, 2;
  return $_[0]->new(%r);
}

sub _parse_head {
  my %r;
  foreach (split /\n/, $_[0]->{_head_content}) {
    my ($k, $v) = split /=/, $_, 2;
    $k =~ s/-/_/g;
    $r{head}->{$k} = $v;
    push @{$r{head_order}}, $k;
  }
  delete $_[0]->{_head_content};
  $_[0]->parse_head_parameters($r{head}, $r{head_order});
}

sub _parse_body {
  my @body;
  foreach (split /\n/, $_[0]->{_body_content}) {
    my ($k, $v) = split /=/, $_, 2;
    $k =~ s/-/_/g;
    push @body, $k, $v;
  }
  delete $_[0]->{_body_content};
  $_[0]->parse_body_parameters(\@body);
}

=head2 C<parse_head_parameters( $head_hash_ref, $head_order )>

This method is called by the constructor to process the fields of the
header of the message.

=cut

sub parse_head_parameters {
  my ($self, $head, $head_order) = @_;
  $self->{_head_order} = $head_order || [qw/hop source target/];

  # process fields from the header
  foreach ([ hop => 1 ],
           [ source => undef ],
           [ target => $STAR ],
          ) {
    my ($param, $default) = @$_;
    my $value;
    if (exists $head->{$param}) {
      $value = $head->{$param};
    } else {
      if (defined $default) {
        $value = $default;
      } else {
        $self->argh("requires '$param' parameter");
      }
    }
    $self->{'_'.$param} = $value;
  }
  return 1;
}

=head2 C<parse_body_parameters( $body_hash_ref )>

This method is called by the constructor to process the fields of the
body of the message according to the field specification for the
message type.

=cut

sub parse_body_parameters {
  my ($self, $body, $body_order) = @_;
  if (ref $body eq 'ARRAY') {
    my @body = @$body; # TOFIX: use index
    while (@body) {
      my ($k, $v) = splice @body, 0, 2;
      if (exists $self->{_body}->{$k}) {
        if (ref $self->{_body}->{$k}) {
          push @{$self->{_body}->{$k}}, $v;
        } else {
          $self->{_body}->{$k} = [$self->{_body}->{$k}, $v];
        }
        next;
      }
      $self->{_body}->{$k} = $v;
      push @{$self->{_body_order}}, $k;
    }
  } else {
    confess "Deprecated\n";
  }
  return 1;
}

=head2 C<summary()>

This method returns a string containing a summary of the xPL message.
It is intended for use when logging.  This method is intended to be
overriden so that specific messages can append brief relevant data
to the common components of the summary.

=cut

sub summary {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  sprintf
    '%s/%s.%s: %s -> %s %s',
      $self->{_message_type},
        $self->{_class}, $self->{_class_type},
          $self->{_source}, $self->{_target},
            $self->body_summary();
}

=head2 C<body_summary()>

This method returns a string containing a summary of the fields from
the body of the xPL message.

=cut

sub body_summary {
  my $self = shift;
  my $str = $self->body_content;
  $str =~ s/^[^=]+=//mg;
  $str =~ s!$LF$!!;
  $str =~ s!$LF!/!g;
  $str;
}

=head2 C<string()>

This method returns the xPL message string.  It is made up of the
L<head_string()> and L<body_string()>.

=cut

sub string {
  my $self = shift;
  $self->head_string(@_).$self->body_string(@_);
}

=head2 C<head_string()>

This method returns the string that makes up the head part of the xPL
message.

=cut

sub head_string {
  my $h = $_[0]->{_message_type}."$LF\{$LF";
  if (defined $_[0]->{_head_content}) {
    $h .= $_[0]->{_head_content}.$LF;
  } else {
    foreach (@{$_[0]->{_head_order}}) {
      $h .= $_.$EQUALS.$_[0]->{'_'.$_}.$LF;
    }
  }
  $h .= "}$LF";
  return $h;
}

=head2 C<body_string()>

This method returns the string that makes up the body part of the xPL
message.

=cut

sub body_string {
  $_[0]->{_class}.$DOT.$_[0]->{_class_type}."$LF\{$LF".
    $_[0]->body_content."}$LF";
}

=head2 C<body_content()>

This method returns the string that makes up the fields of the body
part of the xPL message.

=cut

sub body_content {
  return $_[0]->{_body_content}.$LF if (defined $_[0]->{_body_content});
  my $b = $EMPTY;
  foreach ($_[0]->body_fields()) {
    my $v = $_[0]->{'_body'}->{$_};
    my $n = $_;
    $n = 'remote-ip' if ($_ eq 'remote_ip');
    foreach ((ref $v) ? @{$v} : ($v)) {
      $b .= "$n=".$_."$LF";
    }
  }
  $b;
}

=head2 C<message_type( [ $new_message_type ] )>

This method returns the message type identifier.  If the optional new
value argument is present, then this method updates the message type
identifier with the new value before it returns.

=cut

sub message_type {
  return $_[0]->{_message_type} unless (@_ > 1);
  confess "Deprecated message_type setter\n";
  my $value = $_[1];
  $_[0]->{_message_type} = $value;
}

=head2 C<hop( [ $new_hop ] )>

This method returns the hop count.

=cut

sub hop {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  if (@_) {
    confess "Deprecated hop setter\n";
  }
  return $self->{_hop};
}

sub increment_hop {
  my $self = shift;
  if ($self->{_head_content}) {
    $self->{_head_content} =~ s!^hop=(\d+)$!$1+1!me;
    return $1+1;
  } else {
    $self->{_hop}++;
  }
}

=head2 C<source( [ $new_source ] )>

This method returns the source id.  If the optional new value argument
is present, then this method updates the source id to the new value
before it returns.

=cut

sub source {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  if (@_) {
    confess "Deprecated source setter\n";
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
  $self->_parse_head() if ($self->{_head_content});
  if (@_) {
    confess "Deprecated target setter\n";
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

=head2 C<field( $field )>

This method returns the value of the field from the message
body.

=cut

sub field {
  my $self = shift;
  my $key = shift;
  $self->_parse_body() if ($self->{_body_content});
  $self->{_body}->{$key};
}

=head2 C<body_fields()>

This method returns the fields that are in the body of this message.

=cut

sub body_fields {
  $_[0]->_parse_body() if ($_[0]->{_body_content});
  return @{$_[0]->{_body_order}||[]};
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

Mark Hindess, E<lt>soft-xpl-perl@temporalanomaly.comE<gt>

=head1 COPYRIGHT

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
