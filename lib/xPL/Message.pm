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
                              schema => 'hbeat.app',
                              body =>
                              [
                               interval => 10,
                               port => 12345,
                               remote_ip => '127.0.0.1',
                               extra => 'value in my extra field',
                              ],
                             );

  # let's leave out some fields and let them use the defaults
  $msg = xPL::Message->new(head =>
                           {
                            source => 'acme-lamp.livingroom',
                           },
                           schema => 'hbeat.app',
                           body =>
                           [
                            remote_ip => '127.0.0.1',
                            extra => 'value in my extra field',
                           ],
                          );

=head1 DESCRIPTION

This module creates an xPL message.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;
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

__PACKAGE__->make_readonly_accessor(qw/message_type schema/);

=head2 C<new(%parameter_hash)>

The constructor creates a new xPL::Message object.  The constructor
takes a parameter hash as arguments.  Valid parameters in the hash
are:

=over 4

=item message_type

  The message type identifier.  Valid values are 'xpl-cmnd',
  'xpl-stat' and 'xpl-trig', for each of the three styles of xPL
  Message.

=item schema

  The schema of the message.  It should be the full schema name, such
  as 'hbeat.basic'.

=back

It returns a blessed reference when successful or undef otherwise.

=cut

sub new {
  my $pkg = shift;

  my %p = @_;
  if ($p{validate} || $ENV{XPL_MESSAGE_VALIDATE}) {
    require xPL::ValidatedMessage;
    import xPL::ValidatedMessage;
    return xPL::ValidatedMessage->new(@_);
  }
  my $self = { _verbose => $p{verbose}||0, };
  bless $self, $pkg;

  if (exists $p{class}) {
    warnings::warnif('deprecated',
        '"class" is deprecated. Set "schema" to "class.class_type" instead');
    $p{schema} = $p{class};
    delete $p{class};
    if (exists $p{class_type}) {
      warnings::warnif('deprecated',
                       '"class_type" is deprecated. '.
                       'Set "schema" to "class.class_type" instead');
      $p{schema} .= '.'.$p{class_type};
    }
  }

  defined $p{schema} or $pkg->argh(q{requires 'schema' parameter});
  $self->{_schema} = $p{schema};

  exists $p{message_type} or $pkg->argh(q{requires 'message_type' parameter});
  my $message_type = $p{message_type};
  exists $MESSAGE_TYPES{$message_type} or
    $pkg->argh("message type identifier, $message_type, is invalid.\n".
               'It should be one of xpl-cmnd, xpl-stat or xpl-trig.');

  $self->{_message_type} = $message_type;

  if ($p{head_content}) {
    $self->{_head_content} = $p{head_content};
  } else {
    $self->parse_head_parameters($p{head}||{}, $p{head_order});
  }

  if ($p{body_content}) {
    $self->{_body_content} = $p{body_content};
  } elsif (exists $p{body} && ref $p{body} eq 'HASH') {
    warnings::warnif('deprecated',
                     'Providing "body" hash reference is deprecated. '.
                     'Use an array reference so that order is preserved. '.
                     'For example: [ device => "device", command => "on" ]');
    $self->{_body} = $p{body};
    $self->{_body_order} = $p{body_order} || [sort keys %{$self->{_body}}];
  } else {
    $self->{_body_array} = $p{body} || [];
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
  $r{schema} = $1;
  # strict => 0 is only really needed when xPL::ValidatedMessage's are created
  return $_[0]->new(strict => 0, %r);
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
  $_[0]->{_body_array} = \@body;
  $_[0]->parse_body_parameters();
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

=head2 C<parse_body_parameters( )>

This method is called lazily to convert the body array in to a hash to
make extracting field values more efficient.

=cut

sub parse_body_parameters {
  my ($self) = @_;
  my $body_array = $self->{_body_array};
  my $body = $self->{_body} = {};
  my $body_order = $self->{_body_order} = [];
  my $i = 0;
  while ($i < scalar @$body_array) {
    my $k = $body_array->[$i++];
    my $v = $body_array->[$i++];
    if (exists $body->{$k}) {
      if (ref $body->{$k}) {
        push @{$body->{$k}}, $v;
      } else {
        $body->{$k} = [$body->{$k}, $v];
      }
    } else {
      $body->{$k} = $v;
      push @{$body_order}, $k;
    }
  }
  delete $self->{_body_array};
  return 1;
}

=head2 C<summary()>

This method returns a string containing a summary of the xPL message.
It is intended for use when logging.  This method is intended to be
overridden so that specific messages can append brief relevant data
to the common components of the summary.

=cut

sub summary {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  sprintf
    '%s/%s: %s -> %s %s',
      $self->{_message_type},
        $self->{_schema}, $self->{_source}, $self->{_target},
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
  $_[0]->{_schema}."$LF\{$LF".$_[0]->body_content."}$LF";
}

=head2 C<body_content()>

This method returns the string that makes up the fields of the body
part of the xPL message.

=cut

sub body_content {
  return $_[0]->{_body_content}.$LF if (defined $_[0]->{_body_content});
  my $b = $EMPTY;
  foreach ($_[0]->body_fields()) {
    my $v = $_[0]->field($_);
    my $n = $_;
    $n = 'remote-ip' if ($_ eq 'remote_ip');
    foreach ((ref $v) ? @{$v} : ($v)) {
      $b .= "$n=".$_."$LF";
    }
  }
  $b;
}

=head2 C<message_type( )>

This method returns the message type identifier.

=head2 C<hop( )>

This method returns the hop count.

=cut

sub hop {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  $self->{_hop};
}

=head2 C<source( )>

This method returns the source id.

=cut

sub source {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  $self->{_source};
}

=head2 C<target( )>

This method returns the target id.

=cut

sub target {
  my $self = shift;
  $self->_parse_head() if ($self->{_head_content});
  $self->{_target};
}

=head2 C<schema()>

This method returns the xPL message schema (e.g. "hbeat.basic").

=head2 C<class()>

This method returns the schema class (e.g. "hbeat").

=cut

sub class {
  my $self = shift;
  (split /\./, $self->{_schema}, 2)[0]
}

=head2 C<class_type()>

This method returns the class type (e.g. "basic").

=cut

sub class_type {
  my $self = shift;
  (split /\./, $self->{_schema}, 2)[1]
}

=head2 C<field( $field )>

This method returns the value of the field from the message
body.

=cut

sub field {
  my $self = shift;
  my $key = shift;
  if (exists $self->{_body_content}) {
    $self->_parse_body();
  } elsif (!exists $self->{_body}) {
    $self->parse_body_parameters();
  }
  $self->{_body}->{$key};
}

=head2 C<body_fields()>

This method returns the fields that are in the body of this message.

=cut

sub body_fields {
  if (exists $_[0]->{_body_content}) {
    $_[0]->_parse_body();
  } elsif (!exists $_[0]->{_body}) {
    $_[0]->parse_body_parameters();
  }
  return @{$_[0]->{_body_order}};
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

Copyright (C) 2005, 2009 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
