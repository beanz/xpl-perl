package xPL::SQL;

# $Id$

=head1 NAME

xPL::SQL - Perl extension for xPL database interactions

=head1 SYNOPSIS

  # Environment variable XPL_DB_CONFIG should point to file containing
  # Class::DBI::Loader parameters in the form:
  #
  # dsn=dbi:mysql:xpl
  # user=xpldb
  # password=blahblah
  #
  use xPL::SQL;

  my $m =
    xPL::SQL::Msg->create({
                           time => $time,
                           usec => $usec,
                           type => $msg->message_type,
                           class => $msg->class.'.'.$msg->class_type,
                           source => $msg->source,
                           target => $msg->target,
                           incomplete => 0,
                          });
  foreach my $field ($msg->body_fields) {
    $m->add_to_msgelts(
      {
       elt => xPL::SQL::Elt->find_or_create({
                                             name => $field,
                                             value => $msg->$field,
                                            })
      }
    );
  }

=head1 DESCRIPTION

This module creates some xPL::SQL::* classes for storing xPL related
information in a database.

=head1 METHODS

=cut

use 5.006;
use strict;
use warnings;
use Class::DBI::Loader;
use FileHandle;
use Date::Parse qw/str2time/;
use xPL::Message;
use Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = qw/$Revision$/[1];

my $db = $ENV{XPL_DB_CONFIG} || '/etc/ha/db.config';
my $fh = FileHandle->new($db) or die "Failed to open config, $db: $!\n";
my %args = ();
while (<$fh>) {
  chomp;
  next unless (/^\s*(\w+)\s*=\s*(.*)$/);
  $args{$1} = $2;
}
$fh->close;
my $loader = Class::DBI::Loader->new(%args, namespace => 'xPL::SQL');
xPL::SQL::Msgelt->has_a(msg => 'xPL::SQL::Msg');
xPL::SQL::Msgelt->has_a(elt => 'xPL::SQL::Elt');
package xPL::SQL::Msg;
my @temp = ();
__PACKAGE__->has_many(msgelts => 'xPL::SQL::Msgelt');
__PACKAGE__->has_a(body => 'xPL::SQL::Body');
push @temp, "body_text";
__PACKAGE__->set_sql(last_x10_on => q{
  SELECT msg.*, body.body as body_text
  FROM msg, body
  WHERE msg.class = 'x10.basic' AND
        msg.body = body.id AND
        body.body like CONCAT('command=on\ndevice=',?,'\n%%')
  ORDER BY time DESC, usec DESC LIMIT 1
});
__PACKAGE__->set_sql(time => q{
  SELECT msg.*
  FROM msg
  WHERE time > ?
});
__PACKAGE__->set_sql(last_x10 => q{
  SELECT msg.*, body.body as body_text
  FROM msg, body
  WHERE msg.class = 'x10.basic' AND
        msg.body = body.id AND
        body.body like CONCAT('command=%%\ndevice=',?,'\n%%')
  ORDER BY time DESC, usec DESC LIMIT 1
});
push @temp, "command";
__PACKAGE__->set_sql(x10_history => q{
  SELECT msg.*, body.body as body_text
  FROM msg, body
  WHERE time > ? AND
        msg.class = 'x10.basic' AND msg.type = 'xpl-trig' AND
        msg.body = body.id AND
        body.body like CONCAT('command=%%\ndevice=',?,'\n%%')
  ORDER BY time DESC, usec DESC
});

xPL::SQL::Msg->columns(TEMP => @temp);

sub to_xpl_message {
  my $self = shift;
  my $body = $self->body_text || $self->body->body();
  chomp($body);
  my %args = ();
  foreach (split /\n/, $body) {
    my ($k, $v) = split /=/, $_, 2;
    $k =~ s/-/_/g;
    if (exists $args{body}->{$k}) {
      xPL::Message->ouch('Repeated body field: '.$k);
      next;
    }
    $args{body}->{$k} = $v;
    push @{$args{body_order}}, $k;
  }
  return xPL::Message->new(message_type => $self->type,
                           head =>
                           {
                            hop => 1,
                            source => $self->source,
                            target => $self->target,
                           },
                           class => $self->class,
                           %args,
                          );
}

1;
__END__

=head2 TABLES

Current tables which should work for MySQL are:

  CREATE TABLE body (
    id int NOT NULL auto_increment,
    body varchar(1500) default NULL,
    PRIMARY KEY  (id),
    KEY body_idx (body(1000))
  );

  CREATE TABLE elt (
    id int NOT NULL auto_increment,
    name varchar(16) default NULL,
    value varchar(128) default NULL,
    PRIMARY KEY  (id),
    KEY name_idx (name)
  );

  CREATE TABLE msg (
    id int NOT NULL auto_increment,
    time int default NULL,
    usec int default NULL,
    type char(8) default NULL,
    source varchar(34) default NULL,
    target varchar(34) default NULL,
    class varchar(15) default NULL,
    incomplete int default NULL,
    body int default NULL,
    PRIMARY KEY  (id),
    KEY class_idx (class),
    KEY time_idx (time,usec),
    KEY type_idx (type),
    KEY body_idx (body)
  );

  CREATE TABLE msgelt (
    id int NOT NULL auto_increment,
    msg int NOT NULL,
    elt int NOT NULL,
    PRIMARY KEY  (id),
    KEY msg_idx (msg),
    KEY elt_idx (elt)
  );

=head2 EXPORT

None by default.

=head1 SEE ALSO

Project website: http://www.xpl-perl.org.uk/

=head1 AUTHOR

Mark Hindess, E<lt>xpl-perl@beanz.uklinux.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Mark Hindess

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.

=cut
