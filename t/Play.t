#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;
use-ok 'Play';
use Play;
use RPN;

my @methods=qw<new who type cube bonus_cube dest rpn solutions display>;

my $B=Play.new(type=>'Move',who=>'The_Author',cube=>'^',dest=>'Required',rpn=>RPN.new('11^11@+'));
$B.notes="This is a test play";
isa-ok($B, 'Play', "Fully-specified play:  {$B.display}");

can-ok( $B, $_ ) for @methods;

isa-ok($B=Play.new(type=>'Move',cube=>'7',dest=>'Forbidden'),  'Play', "Valid Regular move to Forbidden:  {$B.display}");
isa-ok($B=Play.new(type=>'Move',cube=>'*',dest=>'Required'),   'Play', "Valid Regular move to Required:   {$B.display}");
isa-ok($B=Play.new(type=>'Move',cube=>'0',dest=>'Permitted'),  'Play', "Valid Regular move to Permitted:  {$B.display}");

isa-ok($B=Play.new(type=>'Bonus',cube=>'0',bonus_cube=>'*',dest=>'Permitted'),  'Play', "Valid Bonus move to Permitted:  {$B.display}");
isa-ok($B=Play.new(type=>'Terminal'),                                           'Play', "Valid Terminal move:  {$B.display}");


dies-ok( { Play.new(type=>'Reg')                                     }, "die on invalid type");
dies-ok( { Play.new(type=>'Move',dest=>'Permitted')                  }, "Regular move die on missing cube");
dies-ok( { Play.new(type=>'Move',dest=>'Permited')                   }, "Regular move die on dest typo");
dies-ok( { Play.new(type=>'Move',cube=>'6')                          }, "Regular move die on missing dest");
dies-ok( { Play.new(type=>'Bonus',bonus_cube=>'/',cube=>'6')         }, "Bonus move die on missing dest");
dies-ok( { Play.new(type=>'Bonus',bonus_cube=>'/',dest=>'Permitted') }, "Bonus move die on missing cube");
dies-ok( { Play.new(type=>'Bonus',dest=>'Permitted',cube=>'6')       }, "Bonus move die on missing bonus_cube");

done-testing;
