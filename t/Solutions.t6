#!/usr/bin/env perl6

use v6;
use Test;

my $lib;

BEGIN { $lib=q{/Users/imel/gitdev/donalgrant/p6-equations/lib} }

use lib $lib;

use Globals;
use RPN;

use-ok 'Solutions';
use Solutions;

my @methods=qw<new save clear elems list values rpn_list found valid_for formable one-away display>;

can-ok( Solutions.new, $_ ) for @methods;

my $S=Solutions.new;
isa-ok( $S, 'Solutions', "Empty Solutions" );

nok( $S.found, "No solutions yet" );

isa-ok( $S.save(RPN.new('11+')), 'Solutions', "save an RPN" );
isa-ok( $S.save('22+'),          'Solutions', "save an RPN-string");

my %rl = '33/' => 1, '14@' => 4, '45+6-8*' => 24;
my @ra = '31/',      '24@',      '45+7-8*';

isa-ok( $S.save( %rl ), 'Solutions', "save an RPN-string hash" );
isa-ok( $S.save( @ra ), 'Solutions', "save an RPN-string array" );

isa-ok( $S.save( %( '333/*' => 3, '14@2+' => 6, '45+6-8*7-' => 17 ) ), 'Solutions', "save an RPN-string anonymous hash" );
isa-ok( $S.save( @( '31/4+',      '24@4+',      '45+7-8*4+') ),        'Solutions', "save an RPN-string anonymous array" );

isa-ok( $S.save( %( RPN.new('55*') => 1, RPN.new('333**') => 0, RPN.new('1234+++') => 11 ) ), 'Solutions', "save RPN hash (hash vals discarded)" );
isa-ok( $S.save( @( RPN.new('78^'),      RPN.new('88^'),        RPN.new('93-2+')) ),          'Solutions', "save RPN array" );

ok( $S.found, "We have some solutions" );
is( $S.elems, 20, "We've add 20 solutions" );

$S.save('333/*');
is( $S.elems, 20, "Duplicate solution doesn't change count" );

$S.save('33/*');
is( $S.elems, 20, "Invalid solution doesn't change count" );

my $v=$S.values.map( *.floor ).Set;  # can get numerical error...
my $e=(6,17,2,2,4,3,3,7,6,24,4,25,10,16,16777216,27,20,1,8,5764801).Set;

ok( $v == $e, "Solution values" );

is( $S.valid_for(3).sort, ( '333/*', '31/' ).sort,                     "Two rpns work for 3" );
is( $S.formable( Bag.new(qw{ 1 3 3 3 4 / * 7 8 8 ^ }) ).sort,
    ( '33/', '31/', '333/*', '78^', '88^' ).sort,                      "formable solutions" );
is( $S.formable( Bag.new(qw{ 1 3 3 3 4 / * 7 8 8 ^ }), Bag.new(qw{ 3 3 / }) ).sort,
    ( '33/', '333/*' ).sort,                                           "formable solutions with 3 3 required" );
is( $S.one-away( Bag.new(qw{ 3 3 3 / }) ).sort,
    ( '31/', '333/*' ).sort,                                           "one-away solutions" );
is( $S.one-away( Bag.new(qw{ 3 3 3 / }), Bag.new(qw{ 1 }) ).sort,
    ( '31/' ).sort,                                                    "one-away solutions with 1 required" );

my @R=$S.rpn_list;
is( @R.elems, 20, "RPN List has correct number of elements" );
isa-ok( @R[0], 'RPN', "First element is RPN" );

ok( $v == @R.map({ (+$_).floor }).Set, "RPN values match values" );

isa-ok( $S.delete(@R[0]),      'Solutions', "can delete RPN" );
isa-ok( $S.delete(@R[1].Str),      'Solutions', "can delete RPN Str");
is( $S.elems, 18, "Number of elements reduced by one after two deletions, one duplicate" );

lives-ok( { note $S.display }, "Can display Solutions" );

done-testing;
