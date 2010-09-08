#!/usr/bin/perl -w
#
# Copyright (C) 2010 by Mark Hindess

use strict;
BEGIN {
  eval { require AnyEvent; import AnyEvent; };
  if ($@) {
    require Test::More;
    import Test::More skip_all => 'AnyEvent not available';
  }
}

do 't/05-listener.t' or die $@;
