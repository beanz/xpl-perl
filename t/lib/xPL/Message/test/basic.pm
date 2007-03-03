package xPL::Message::test::basic;
#
# Copyright (C) 2005, 2006 by Mark Hindess

use xPL::Message;
our @ISA = qw(xPL::Message);
sub field {
  return "field not overriden";
}
sub body_fields {
  return "body_fields not overriden";
}
sub field_spec {
  [
   {
    name => 'field',
    validation => xPL::Validation->new(type => 'Set', set => ['a','b']),
   },
  ];
}
sub default_message_type { return 'xpl-trig' }

1;
